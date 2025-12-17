module Billing
  class PriceKeyResolver
    def self.key_for_price_id(price_id)
      return nil if price_id.blank?

      ConfiguredPrices::PRICE_KEYS.each do |key, env_key|
        return key.to_s if ENV[env_key] == price_id
      end

      nil
    end
  end
end

