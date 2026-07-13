module Licenses
  class ManualSubscriptionSync
    def initialize(manual_subscription_id:, encoder: LicenseKeyEncoder.new, logger: Rails.logger)
      @manual_subscription_id = manual_subscription_id
      @encoder = encoder
      @logger = logger
    end

    def call
      subscription = ManualSubscription.find_by(id: manual_subscription_id)
      return unless subscription
      return if subscription.superseded?

      user = subscription.user
      plan = subscription.billing_plan
      return unless user.is_a?(User)
      return unless plan&.subscription?

      stripe_result = Billing::ActiveSubscriptionFinder.new(user: user).call
      if stripe_result.stripe?
        subscription.supersede_with!(pay_subscription: stripe_result.subscription)
        return
      end

      tier = plan.tier
      interval = plan.interval_key
      return unless tier && interval

      logger.info("[Licenses::ManualSubscriptionSync] syncing manual_subscription_id=#{subscription.id} user_id=#{user.id} tier=#{tier} interval=#{interval}")

      allowed_eas = ExpertAdvisor.active.includes(:billing_plan_entitlements, :billing_plans)
                                 .select { |ea| ea.allowed_for_tier?(tier) }
      allowed_ids = allowed_eas.map(&:id)

      mark_referral_completed(user: user) if subscription.active_for_time?

      allowed_eas.each do |expert_advisor|
        sync_license_for(user: user, expert_advisor: expert_advisor, interval: interval, subscription: subscription)
      end

      expire_disallowed_licenses(user: user, allowed_ids: allowed_ids)
    rescue StandardError => e
      logger.error("[Licenses::ManualSubscriptionSync] failed manual_subscription_id=#{manual_subscription_id}: #{e.class} - #{e.message}")
      raise
    end

    private

    attr_reader :manual_subscription_id, :encoder, :logger

    def sync_license_for(user:, expert_advisor:, interval:, subscription:)
      license = License.find_or_initialize_by(user: user, expert_advisor: expert_advisor)
      license.with_lock do
        return if license.access_source_one_time?

        manual_scope = ManualSubscription.where(user: user, status: ManualSubscription::STATUSES[:active])
        effective_ends_at = manual_scope.maximum(:ends_at) || subscription.ends_at
        currently_active = manual_scope.active_at(Time.current).exists?

        license.access_source = "subscription"
        license.plan_interval = interval
        license.source = "manual_subscription"
        license.last_synced_at = Time.current
        license.trial_ends_at = nil
        license.status = currently_active ? "active" : "expired"
        license.expires_at = effective_ends_at
        license.encrypted_key = encoder.generate(**license.token_generation_attributes)
        license.save!
      end
    end

    def expire_disallowed_licenses(user:, allowed_ids:)
      return if allowed_ids.blank?

      disallowed_scope = License.where(user: user)
      disallowed_scope = disallowed_scope.where.not(expert_advisor_id: allowed_ids) if allowed_ids.present?

      disallowed_scope.find_each do |license|
        next if license.access_source_one_time?
        next if license.trial? && !license.trial_expired?
        next if license.expired? || license.revoked?

        license.update(
          status: "expired",
          last_synced_at: Time.current,
          expires_at: license.expires_at || Time.current
        )
      end
    end

    def mark_referral_completed(user:)
      Referrals::MarkCompleted.new(user: user).call
    rescue StandardError => e
      logger.warn("[Licenses::ManualSubscriptionSync] referral completion failed user_id=#{user.id}: #{e.class} - #{e.message}")
    end
  end
end
