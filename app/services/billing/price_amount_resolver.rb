module Billing
  class PriceAmountResolver
    def initialize(pricing_catalog: nil, stripe_fallback: false, logger: Rails.logger)
      @pricing_catalog = pricing_catalog
      @stripe_fallback = stripe_fallback
      @logger = logger
      @amount_cache = {}
      @price_id_cache = {}
    end

    def amount_cents_for(price_key)
      return if price_key.blank?

      return @amount_cache[price_key] if @amount_cache.key?(price_key)

      from_catalog = amount_from_catalog(price_key)
      amount = if from_catalog.present?
                 from_catalog
               elsif stripe_fallback?
                 price_id = Billing::ConfiguredPrices.price_id_for(price_key)
                 amount_from_stripe(price_id)
               end

      @amount_cache[price_key] = amount
    end

    def amount_cents_for_price_id(price_id)
      return if price_id.blank?
      return unless stripe_fallback?

      @price_id_cache[price_id] ||= amount_from_stripe(price_id)
    end

    private

    attr_reader :pricing_catalog, :logger

    def stripe_fallback?
      @stripe_fallback && ENV["STRIPE_PRIVATE_KEY"].present?
    end

    def amount_from_catalog(price_key)
      return if pricing_catalog.blank?

      tier, interval = parse_price_key(price_key)
      return if tier.blank? || interval.blank?

      if interval == "annual"
        pricing_catalog.dig(:annual, tier, :amount_cents)
      else
        pricing_catalog.dig(:monthly, tier, :amount_cents)
      end
    end

    def amount_from_stripe(price_id)
      return if price_id.blank?

      Stripe.api_key = ENV["STRIPE_PRIVATE_KEY"]
      stripe_price = Stripe::Price.retrieve(price_id)
      stripe_price&.unit_amount
    rescue StandardError => e
      logger.warn("[Billing::PriceAmountResolver] failed price_id=#{price_id}: #{e.class} - #{e.message}")
      nil
    end

    def parse_price_key(price_key)
      parts = price_key.to_s.split("_")
      return [nil, nil] if parts.size < 2

      [parts.first.to_sym, parts.last]
    end
  end
end
