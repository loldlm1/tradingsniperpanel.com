module Billing
  class ConfiguredPrices
    def self.price_id_for(key)
      return if key.blank?

      BillingPlan.purchasable.find_by(key: key)&.stripe_price_id
    end

    def self.price_id_for_tier(tier, interval_key)
      return if tier.blank? || interval_key.blank?

      BillingPlan.purchasable.find_by(tier: tier.to_s, key: "#{tier}_#{interval_key}")&.stripe_price_id
    end

    def self.all_price_ids
      plan_ids = BillingPlan.where.not(stripe_price_id: nil).pluck(:stripe_price_id)
      history_ids = BillingPlanPrice.table_exists? ? BillingPlanPrice.pluck(:stripe_price_id) : []
      (plan_ids + history_ids + legacy_env_price_ids).uniq
    end

    def self.resolve_price_id(value)
      return if value.blank?
      return value if BillingPlan.for_price_id(value).present?

      if product_id?(value)
        plan = BillingPlan.for_product_id(value)
        return plan.stripe_price_id if plan&.stripe_price_id.present?

        return resolve_price_id_from_stripe(value) if stripe_enabled?
      end

      Stripe::Price.retrieve(value)&.id if stripe_enabled?
    rescue StandardError => e
      Rails.logger.warn("ConfiguredPrices.resolve_price_id failed for #{value}: #{e.class} - #{e.message}")
      nil
    end

    def self.product_id?(value)
      value.to_s.start_with?("prod_")
    end

    def self.stripe_enabled?
      ENV["STRIPE_PRIVATE_KEY"].present?
    end

    def self.resolve_price_id_from_stripe(product_id)
      Stripe.api_key = ENV["STRIPE_PRIVATE_KEY"]
      product = Stripe::Product.retrieve(product_id)
      default_price = product&.respond_to?(:default_price) ? product.default_price : nil
      default_price_id = default_price.respond_to?(:id) ? default_price.id : default_price
      return default_price_id if default_price_id.present?

      prices = Stripe::Price.list(product: product_id, limit: 1)
      prices.data.first&.id
    end

    def self.legacy_env_price_id(key)
      env_key = "STRIPE_PRICE_#{key.to_s.upcase}"
      ENV[env_key].presence
    end

    def self.legacy_env_price_ids
      ENV.keys.grep(/\ASTRIPE_PRICE_/).map { |env_key| ENV[env_key].presence }.compact
    end
  end
end
