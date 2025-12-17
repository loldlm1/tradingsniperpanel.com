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
      env_key ? ENV[env_key] : nil
    end

    def self.price_id_for_tier(tier, interval)
      price_id_for("#{tier}_#{interval}")
    end

    def self.all_price_ids
      PRICE_KEYS.values.filter_map { |env_key| ENV[env_key].presence }
    end
  end
end

