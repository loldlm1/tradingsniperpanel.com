module Billing
  class SubscriptionPlanResolver
    def initialize(subscription:)
      @subscription = subscription
    end

    def plan
      return subscription.billing_plan if subscription.respond_to?(:billing_plan)

      price_id = subscription&.processor_plan
      return nil if price_id.blank?

      BillingPlan.for_price_id(price_id) || BillingPlan.for_key(price_key)
    end

    def tier
      plan&.tier || parsed_tier
    end

    def interval_key
      plan&.interval_key || parsed_interval
    end

    private

    attr_reader :subscription

    def price_key
      price_id = subscription&.processor_plan
      return nil if price_id.blank?

      Billing::PriceKeyResolver.key_for_price_id(price_id)
    end

    def parsed_tier
      parts = price_key.to_s.split("_")
      parts.first
    end

    def parsed_interval
      parts = price_key.to_s.split("_")
      return nil if parts.size < 2

      parts.drop(1).join("_")
    end
  end
end
