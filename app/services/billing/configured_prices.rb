module Billing
  class ConfiguredPrices
    PRICE_KEYS = {
      basic_monthly: "STRIPE_PRICE_BASIC_MONTHLY",
      basic_annual: "STRIPE_PRICE_BASIC_ANNUAL",
      hft_monthly: "STRIPE_PRICE_HFT_MONTHLY",
      hft_annual: "STRIPE_PRICE_HFT_ANNUAL",
      pro_monthly: "STRIPE_PRICE_PRO_MONTHLY",
      pro_annual: "STRIPE_PRICE_PRO_ANNUAL"
    }.freeze

    def self.price_id_for(key)
      return if key.blank?

      env_key = PRICE_KEYS[key.to_s.to_sym]
      raw_value = env_key ? ENV[env_key] : nil
      resolve_price_id(raw_value)
    end

    def self.price_id_for_tier(tier, interval)
      price_id_for("#{tier}_#{interval}")
    end

    def self.all_price_ids
      PRICE_KEYS.values.filter_map { |env_key| ENV[env_key].presence }
    end

    def self.resolve_price_id(value)
      return if value.blank?
      return value unless product_id?(value)

      Stripe.api_key = ENV["STRIPE_PRIVATE_KEY"]
      product = Stripe::Product.retrieve(value)
      default_price_id = product&.respond_to?(:default_price) ? product.default_price : nil
      return default_price_id if default_price_id.present?

      Stripe::Price.retrieve(value)&.id
    rescue StandardError => e
      Rails.logger.warn("ConfiguredPrices.resolve_price_id failed for #{value}: #{e.class} - #{e.message}")
      nil
    end

    def self.product_id?(value)
      value.to_s.start_with?("prod_")
    end
  end
end
