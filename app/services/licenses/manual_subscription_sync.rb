module Licenses
  class ManualSubscriptionSync
    def initialize(manual_subscription_id:, encoder: LicenseKeyEncoder.new, logger: Rails.logger)
      @manual_subscription_id = manual_subscription_id
      @encoder = encoder
      @logger = logger
    end

    def call
      requested_subscription = ManualSubscription.find_by(id: manual_subscription_id)
      return unless requested_subscription
      return if requested_subscription.superseded?

      user = requested_subscription.user
      plan = requested_subscription.billing_plan
      return unless user.is_a?(User)
      return unless plan&.subscription?

      stripe_result = Billing::ActiveSubscriptionFinder.new(user: user).call
      if stripe_result.stripe?
        requested_subscription.supersede_with!(pay_subscription: stripe_result.subscription)
        return
      end

      subscription = ManualSubscription.where(user: user).effective_at(Time.current)
      unless subscription
        expire_subscription_licenses(user: user)
        return
      end

      plan = subscription.billing_plan

      interval = plan.interval_key
      product = Billing::SubscriptionCatalog.product_for_plan(plan)
      return unless plan.subscription? && plan.tier.present? && interval.present?
      return if Billing::SubscriptionCatalog.plan_keys.include?(plan.key.to_s) && product.nil?

      allowed_eas = if product
        exact_entitlements_for(plan, subscription)
      else
        ExpertAdvisor.active.includes(:billing_plan_entitlements, :billing_plans)
                   .select { |ea| ea.allowed_for_tier?(plan.tier) }
      end
      return if product && allowed_eas.empty?

      logger.info("[Licenses::ManualSubscriptionSync] syncing manual_subscription_id=#{subscription.id} user_id=#{user.id} tier=#{plan.tier} interval=#{interval}")

      allowed_ids = allowed_eas.map(&:id)

      mark_referral_completed(user: user) if subscription.active_for_time?
      effective_ends_at = effective_end_for(user: user, subscription: subscription)

      allowed_eas.each do |expert_advisor|
        sync_license_for(
          user: user,
          expert_advisor: expert_advisor,
          interval: interval,
          subscription: subscription,
          expires_at: effective_ends_at
        )
      end

      expire_disallowed_licenses(user: user, allowed_ids: allowed_ids)
    rescue StandardError => e
      logger.error("[Licenses::ManualSubscriptionSync] failed manual_subscription_id=#{manual_subscription_id}: #{e.class} - #{e.message}")
      raise
    end

    private

    attr_reader :manual_subscription_id, :encoder, :logger

    def exact_entitlements_for(plan, subscription)
      records = ExpertAdvisor.subscription_entitlements_for(plan)
      return records if records.present?

      logger.warn(
        "[Licenses::ManualSubscriptionSync] canonical entitlements missing manual_subscription_id=#{subscription.id} plan_id=#{plan.id}"
      )
      []
    end

    def sync_license_for(user:, expert_advisor:, interval:, subscription:, expires_at:)
      license = License.find_or_initialize_by(user: user, expert_advisor: expert_advisor)
      license.with_lock do
        return if license.active_one_time_access?

        license.access_source = "subscription"
        license.plan_interval = interval
        license.source = "manual_subscription"
        license.last_synced_at = Time.current
        license.trial_ends_at = nil
        license.status = subscription.active_for_time? ? "active" : "expired"
        license.expires_at = expires_at
        license.encrypted_key = encoder.generate(**license.token_generation_attributes)
        license.save!
      end
    end

    def expire_disallowed_licenses(user:, allowed_ids:)
      disallowed_scope = License.where(user: user, access_source: License.access_sources.fetch("subscription"))
      disallowed_scope = disallowed_scope.where.not(expert_advisor_id: allowed_ids) if allowed_ids.present?

      disallowed_scope.find_each do |license|
        next if license.active_one_time_access?
        next if license.trial? && !license.trial_expired?
        next if license.expired? || license.revoked?

        license.update(
          status: "expired",
          last_synced_at: Time.current,
          expires_at: license.expires_at || Time.current
        )
      end
    end

    def expire_subscription_licenses(user:)
      expire_disallowed_licenses(user: user, allowed_ids: [])
    end

    def effective_end_for(user:, subscription:)
      end_at = subscription.ends_at
      candidates = ManualSubscription.where(user: user)
                                     .where.not(status: [ ManualSubscription::STATUSES[:cancelled], ManualSubscription::STATUSES[:superseded] ])
                                     .where("starts_at >= ?", subscription.starts_at)
                                     .order(:starts_at, :id)

      candidates.each do |candidate|
        break if candidate.starts_at > end_at
        break unless candidate.billing_plan_id == subscription.billing_plan_id
        end_at = candidate.ends_at if candidate.ends_at > end_at
      end

      end_at
    end

    def mark_referral_completed(user:)
      Referrals::MarkCompleted.new(user: user).call
    rescue StandardError => e
      logger.warn("[Licenses::ManualSubscriptionSync] referral completion failed user_id=#{user.id}: #{e.class} - #{e.message}")
    end
  end
end
