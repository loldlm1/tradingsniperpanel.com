module Licenses
  class SubscriptionLicenseSync
    def initialize(subscription_id:, encoder: LicenseKeyEncoder.new)
      @subscription_id = subscription_id
      @encoder = encoder
    end

    def call
      subscription = Pay::Subscription.find_by(id: subscription_id)
      return unless subscription

      customer = subscription.customer
      user = customer&.owner
      return unless user.is_a?(User)

      price_key = Billing::PriceKeyResolver.key_for_price_id(subscription.processor_plan)
      tier, interval = parse_price_key(price_key)
      return unless tier && interval

      Rails.logger.info("[Licenses::SubscriptionLicenseSync] syncing subscription_id=#{subscription.id} user_id=#{user.id} price_key=#{price_key} tier=#{tier} interval=#{interval}")

      allowed_eas = ExpertAdvisor.active.select { |ea| ea.allowed_for_tier?(tier) }
      allowed_ids = allowed_eas.map(&:id)

      allowed_eas.each do |ea|
        sync_license_for(user:, expert_advisor: ea, interval:, subscription:)
      end

      expire_disallowed_licenses(user:, allowed_ids:)
    end

    private

    attr_reader :subscription_id, :encoder

    def parse_price_key(price_key)
      parts = price_key.to_s.split("_")
      return if parts.size < 2

      [parts.first, parts.last]
    end

    def sync_license_for(user:, expert_advisor:, interval:, subscription:)
      license = License.find_or_initialize_by(user:, expert_advisor:)
      license.with_lock do
        license.encrypted_key = encoder.generate(email: user.email, ea_id: expert_advisor.ea_id)
        license.plan_interval = interval
        license.source = "stripe_subscription"
        license.last_synced_at = Time.current
        license.trial_ends_at = subscription.trial_ends_at if subscription.trial_ends_at.present?
        license.status = subscription_active?(subscription) ? "active" : "expired"
        license.trial_ends_at = nil if license.active?
        license.expires_at = subscription.current_period_end || subscription.ends_at || license.expires_at
        license.save!
      end
    end

    def subscription_active?(subscription)
      return false if subscription.nil?

      active_until = subscription.current_period_end || subscription.ends_at
      return true if active_until.nil?

      active_until.future?
    end

    def expire_disallowed_licenses(user:, allowed_ids:)
      return if allowed_ids.blank?

      disallowed_scope = License.where(user:)
      disallowed_scope = disallowed_scope.where.not(expert_advisor_id: allowed_ids) if allowed_ids.present?

      disallowed_scope.find_each do |license|
        next if license.trial? && !license.trial_expired?
        next if license.expired? || license.revoked?

        license.update(
          status: "expired",
          last_synced_at: Time.current,
          expires_at: license.expires_at || Time.current
        )
      end
    end
  end
end
