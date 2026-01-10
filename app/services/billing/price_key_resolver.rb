module Billing
  class PriceKeyResolver
    def self.key_for_price_id(price_id)
      plan = BillingPlan.for_price_id(price_id)
      return plan.key if plan

      legacy_key_for_value(price_id)
    end

    def self.key_for_product_id(product_id)
      plan = BillingPlan.for_product_id(product_id)
      return plan.key if plan

      legacy_key_for_value(product_id)
    end

    def self.legacy_key_for_value(value)
      return nil if value.blank?

      ENV.each do |env_key, env_value|
        next unless env_key.start_with?("STRIPE_PRICE_")
        next unless env_value == value

        return env_key.delete_prefix("STRIPE_PRICE_").downcase
      end

      nil
    end
  end
end
