module Billing
  class PriceKeyResolver
    def self.key_for_price_id(price_id)
      return nil if price_id.blank?

      ConfiguredPrices::PRICE_KEYS.each do |key, env_key|
        env_val = ENV[env_key]
        resolved = Billing::ConfiguredPrices.resolve_price_id(env_val)
        return key.to_s if env_val == price_id || resolved == price_id
      end

      nil
    end

    def self.key_for_product_id(product_id)
      return nil if product_id.blank?

      ConfiguredPrices::PRICE_KEYS.each do |key, env_key|
        env_val = ENV[env_key]
        return key.to_s if env_val == product_id
      end

      nil
    end
  end
end
