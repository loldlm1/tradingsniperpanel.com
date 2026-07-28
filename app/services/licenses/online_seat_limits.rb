module Licenses
  class OnlineSeatLimits
    BASE_SUBSCRIPTION_CAP = 5
    MAX_SUBSCRIPTION_CAP = 13
    ONE_TIME_CAP_PER_EA = 8

    def initialize(user:, expert_advisor:, now: Time.current)
      @user = user
      @expert_advisor = expert_advisor
      @now = now
    end

    def subscription_cap
      tier = active_subscription_tier
      return 0 if tier.blank?

      catalog_cap = Billing::SubscriptionCatalog.seat_cap_for(tier)
      return catalog_cap if catalog_cap

      [ BASE_SUBSCRIPTION_CAP + tier_rank_for(tier), MAX_SUBSCRIPTION_CAP ].min
    end

    def one_time_cap
      one_time_entitled? ? ONE_TIME_CAP_PER_EA : 0
    end

    def active_subscription_tier
      tiers = active_subscription_tiers
      return nil if tiers.empty?

      tiers.max_by { |tier| tier_rank_for(tier) }
    end

    def active_subscription_tiers
      (pay_subscription_tiers + manual_subscription_tiers).compact.map(&:to_s).reject(&:blank?).uniq
    end

    def one_time_entitled?
      license = License.find_by(
        user_id: user.id,
        expert_advisor_id: expert_advisor.id,
        access_source: License.access_sources[:one_time]
      )
      license.present? && license.active_for_request?
    end

    private

    attr_reader :user, :expert_advisor, :now

    def pay_subscription_tiers
      user.pay_customers.includes(:subscriptions).flat_map do |customer|
        customer.subscriptions.active.filter_map do |subscription|
          tier_for_subscription(subscription)
        end
      end
    end

    def manual_subscription_tiers
      ManualSubscription
        .active_at(now)
        .where(user_id: user.id)
        .includes(:billing_plan)
        .filter_map { |subscription| subscription.billing_plan&.tier }
    end

    def tier_for_subscription(subscription)
      plan = BillingPlan.for_price_id(subscription.processor_plan)
      key = Billing::PriceKeyResolver.key_for_price_id(subscription.processor_plan)
      plan ||= BillingPlan.for_key(key)

      return plan.tier if plan&.tier.present?

      parse_tier_from_key(key)
    end

    def parse_tier_from_key(key)
      parts = key.to_s.split("_")
      return nil if parts.size < 2

      parts.first
    end

    def tier_rank_for(tier)
      Billing::SubscriptionCatalog.access_rank_for(tier) || ordered_tiers.index(tier.to_s) || 0
    end

    def ordered_tiers
      @ordered_tiers ||= BillingPlan.subscription_tiers.map { |plan| plan.tier.to_s }
    end
  end
end
