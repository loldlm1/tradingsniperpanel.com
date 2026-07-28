module Billing
  class SubscriptionPlanResolver
    def initialize(subscription:)
      @subscription = subscription
    end

    def plan
      if subscription.respond_to?(:billing_plan) && subscription.billing_plan.present?
        return subscription.billing_plan
      end

      price_id = subscription&.processor_plan
      return nil if price_id.blank?

      Billing::SubscriptionCatalog.resolve_plan(
        plan_key: price_key,
        price_id: price_id,
        product_id: processor_product_id
      )
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
      parsed_plan.fetch(:tier)
    end

    def parsed_interval
      parsed_plan.fetch(:interval_key)
    end

    def parsed_plan
      @parsed_plan ||= Billing::SubscriptionCatalog.parse_plan_key(price_key)
    end

    def processor_product_id
      return subscription.processor_product if subscription.respond_to?(:processor_product)

      object = subscription.respond_to?(:object) ? subscription.object : nil
      object = subscription.data if object.blank? && subscription.respond_to?(:data)
      return unless object.is_a?(Hash)

      direct = object["product"] || object[:product]
      direct ||= object.dig("plan", "product") || object.dig(:plan, :product)
      direct = direct["id"] || direct[:id] if direct.is_a?(Hash)
      direct.to_s.presence
    end
  end
end
