module Licenses
  class BackfillChuSubscriptionLicenses
    Result = Struct.new(
      :dry_run,
      :scanned,
      :eligible,
      :created,
      :repaired,
      :unchanged,
      :skipped,
      :skipped_one_time,
      :failed,
      :failed_user_ids,
      keyword_init: true
    ) do
      def failed?
        failed.to_i.positive?
      end

      def summary
        {
          dry_run: dry_run,
          scanned: scanned,
          eligible: eligible,
          created: created,
          repaired: repaired,
          unchanged: unchanged,
          skipped: skipped,
          skipped_one_time: skipped_one_time,
          failed: failed,
          failed_user_ids: failed_user_ids
        }
      end
    end

    DEFAULT_BATCH_SIZE = 100
    CHU_EA_ID = Billing::ChuSniperPricing::TIER
    PANDORA_TIER = Billing::PandoraPricing::TIER

    def initialize(
      dry_run: true,
      batch_size: DEFAULT_BATCH_SIZE,
      user_ids: nil,
      now: Time.current,
      encoder: LicenseKeyEncoder.new,
      subscription_finder: Billing::ActiveSubscriptionFinder,
      status_resolver: Billing::SubscriptionStatus,
      logger: Rails.logger
    )
      @dry_run = !!dry_run
      @batch_size = Integer(batch_size)
      raise ArgumentError, "batch_size must be positive" unless @batch_size.positive?

      @user_ids = Array(user_ids).map { |value| Integer(value) }.uniq
      @now = now
      @encoder = encoder
      @subscription_finder = subscription_finder
      @status_resolver = status_resolver
      @logger = logger
    end

    def call
      result = Result.new(
        dry_run: dry_run,
        scanned: 0,
        eligible: 0,
        created: 0,
        repaired: 0,
        unchanged: 0,
        skipped: 0,
        skipped_one_time: 0,
        failed: 0,
        failed_user_ids: []
      )

      candidate_users.find_in_batches(batch_size: batch_size).with_index do |users, batch_index|
        logger.info(
          "[Licenses::BackfillChuSubscriptionLicenses] batch=#{batch_index + 1} size=#{users.size} " \
          "first_user_id=#{users.first.id} last_user_id=#{users.last.id} dry_run=#{dry_run}"
        )
        users.each { |user| process_user(user, result) }
      end

      logger.info(
        "[Licenses::BackfillChuSubscriptionLicenses] complete " \
        "scanned=#{result.scanned} eligible=#{result.eligible} created=#{result.created} " \
        "repaired=#{result.repaired} unchanged=#{result.unchanged} skipped=#{result.skipped} " \
        "failed=#{result.failed} dry_run=#{dry_run}"
      )
      result
    end

    private

    attr_reader :dry_run, :batch_size, :user_ids, :now, :encoder, :subscription_finder, :status_resolver, :logger

    def candidate_users
      stripe_users = User.where(id: stripe_candidate_user_ids)
      manual_users = User.where(id: manual_candidate_user_ids)
      relation = stripe_users.or(manual_users)
      relation = relation.where(id: user_ids) if user_ids.present?
      relation
    end

    def stripe_candidate_user_ids
      price_ids = pandora_price_ids
      return User.none.select(:id) if price_ids.empty?

      customer_ids = Pay::Subscription
        .where(processor_plan: price_ids, status: %w[active trialing])
        .where("ends_at IS NULL OR ends_at > ?", now)
        .select(:customer_id)

      Pay::Customer.where(owner_type: "User", id: customer_ids).select(:owner_id)
    end

    def manual_candidate_user_ids
      ManualSubscription
        .active_at(now)
        .joins(:billing_plan)
        .where(billing_plans: { tier: PANDORA_TIER, key: Billing::PandoraPricing::PLAN_KEYS })
        .select(:user_id)
    end

    def pandora_price_ids
      plan_ids = BillingPlan.where(
        tier: PANDORA_TIER,
        key: Billing::PandoraPricing::PLAN_KEYS,
        kind: BillingPlan.kinds.fetch("subscription")
      ).pluck(:id)
      return [] if plan_ids.empty?

      direct_ids = BillingPlan.where(id: plan_ids).pluck(:stripe_price_id)
      history_ids = BillingPlanPrice.where(billing_plan_id: plan_ids).pluck(:stripe_price_id)
      (direct_ids + history_ids).compact_blank.uniq
    end

    def process_user(user, result)
      result.scanned += 1
      context = access_context_for(user)
      unless context
        result.skipped += 1
        return
      end

      result.eligible += 1
      outcome = synchronize_user(user, context)
      result.public_send("#{outcome}=", result.public_send(outcome).to_i + 1)
    rescue StandardError => e
      result.failed += 1
      result.failed_user_ids << user.id
      logger.error(
        "[Licenses::BackfillChuSubscriptionLicenses] failed user_id=#{user.id} error=#{e.class}"
      )
    end

    def access_context_for(user)
      access = subscription_finder.new(user: user).call
      subscription = access.subscription
      return unless subscription

      plan = plan_for(subscription)
      product = Billing::SubscriptionCatalog.product_for_plan(plan)
      return unless product&.tier == PANDORA_TIER
      return unless plan.interval_key.present?

      source = access.source&.to_sym
      if source == :stripe
        return unless status_resolver.new(subscription).paid_active?
      elsif source == :manual
        return unless subscription.active_for_time?(now)
      else
        return
      end

      expires_at = subscription.current_period_end || subscription.ends_at
      return unless expires_at.present? && expires_at > now

      chu_ea = ExpertAdvisor.active.find_by(ea_id: CHU_EA_ID)
      return unless chu_ea

      entitled_eas = ExpertAdvisor.subscription_entitlements_for(plan)
      return unless entitled_eas.any? { |expert_advisor| expert_advisor.id == chu_ea.id }

      {
        expert_advisor: chu_ea,
        interval: plan.interval_key,
        expires_at: expires_at,
        source: source == :manual ? "manual_subscription" : "stripe_subscription"
      }
    end

    def plan_for(subscription)
      if subscription.respond_to?(:billing_plan)
        return subscription.billing_plan
      end

      price_id = subscription.processor_plan
      price_key = Billing::PriceKeyResolver.key_for_price_id(price_id)
      BillingPlan.for_price_id(price_id) || BillingPlan.for_key(price_key)
    end

    def synchronize_user(user, context)
      return classify_license(user, context) if dry_run

      outcome = nil
      ApplicationRecord.transaction(requires_new: true) do
        user.lock!
        license = License.lock.find_by(user: user, expert_advisor: context.fetch(:expert_advisor))
        if license&.active_one_time_access?
          outcome = :skipped_one_time
          next
        end

        outcome = synchronize_license(user, license, context)
      end
      outcome
    end

    def classify_license(user, context)
      license = License.find_by(user: user, expert_advisor: context.fetch(:expert_advisor))
      return :created unless license
      return :skipped_one_time if license.active_one_time_access?
      return :unchanged if license_matches?(license, context)

      :repaired
    end

    def synchronize_license(user, license, context)
      return :created if license.nil? && build_license(user, context)

      return :unchanged if license_matches?(license, context)

      key_matches = key_matches?(license, context)
      assign_subscription_attributes(license, context)
      license.encrypted_key = generated_key(license) unless key_matches
      license.save!
      :repaired
    end

    def build_license(user, context)
      license = License.new(user: user, expert_advisor: context.fetch(:expert_advisor))
      assign_subscription_attributes(license, context)
      license.encrypted_key = generated_key(license)
      license.save!
      true
    end

    def assign_subscription_attributes(license, context)
      license.access_source = "subscription"
      license.plan_interval = context.fetch(:interval)
      license.source = context.fetch(:source)
      license.status = "active"
      license.trial_ends_at = nil
      license.expires_at = context.fetch(:expires_at)
      license.last_synced_at = now
    end

    def generated_key(license)
      encoder.generate(**license.token_generation_attributes)
    end

    def license_matches?(license, context)
      return false unless license.access_source_subscription?
      return false unless license.active?
      return false unless license.plan_interval == context.fetch(:interval)
      return false unless license.source == context.fetch(:source)
      return false unless license.trial_ends_at.nil?
      return false unless license.expires_at == context.fetch(:expires_at)
      return false if license.encrypted_key.blank?

      key_matches?(license, context)
    end

    def key_matches?(license, context)
      return false if license.encrypted_key.blank?

      encoder.valid_key?(
        license_key: license.encrypted_key,
        email: license.user.email,
        ea_id: license.expert_advisor.ea_id,
        expires_at: context.fetch(:expires_at),
        token_version: license.token_version
      )
    end
  end
end
