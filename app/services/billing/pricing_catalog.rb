require "digest"

module Billing
  class PricingCatalog
    CACHE_VERSION = 1
    TIERS = %i[basic hft pro].freeze

    def call
      return {} if Rails.env.test?
      return {} unless ENV["STRIPE_SECRET_KEY"].present?

      price_ids = Billing::ConfiguredPrices.all_price_ids
      return {} if price_ids.empty?

      cache_key = "billing/pricing_catalog/v#{CACHE_VERSION}/#{Digest::SHA256.hexdigest(price_ids.join(':'))}"
      Rails.cache.fetch(cache_key, expires_in: 12.hours) do
        build_catalog
      end
    end

    private

    def build_catalog
      monthly = TIERS.index_with do |tier|
        price_details(Billing::ConfiguredPrices.price_id_for_tier(tier, :monthly))
      end.compact_blank

      annual_raw = TIERS.index_with do |tier|
        price_details(Billing::ConfiguredPrices.price_id_for_tier(tier, :annual))
      end.compact_blank

      annual = annual_raw.transform_values do |details|
        effective_monthly_cents = details[:amount_cents] ? (details[:amount_cents] / 12.0) : nil
        details.merge(
          effective_monthly_cents: effective_monthly_cents,
          effective_monthly_display: format_amount(effective_monthly_cents)
        )
      end

      {
        monthly: monthly,
        annual: annual.merge(discount_percent: discount_percent(monthly: monthly, annual: annual))
      }
    rescue StandardError => e
      Rails.logger.error("Billing::PricingCatalog failed: #{e.class} - #{e.message}")
      {}
    end

    def price_details(price_or_product_id)
      return if price_or_product_id.blank?

      stripe_price = retrieve_price_or_product_default(price_or_product_id)
      return unless stripe_price&.unit_amount

      amount_cents = stripe_price.unit_amount.to_i
      {
        amount_cents: amount_cents,
        currency: stripe_price.currency,
        display: format_amount(amount_cents)
      }
    end

    def retrieve_price_or_product_default(price_or_product_id)
      Stripe.api_key = ENV["STRIPE_SECRET_KEY"]

      if product_id?(price_or_product_id)
        product = Stripe::Product.retrieve(price_or_product_id)
        default_price_id = product&.respond_to?(:default_price) ? product.default_price : nil
        return Stripe::Price.retrieve(default_price_id) if default_price_id.present?
      end

      Stripe::Price.retrieve(price_or_product_id)
    rescue StandardError => e
      Rails.logger.warn("Stripe price lookup failed: #{price_or_product_id} (#{e.class}: #{e.message})")
      nil
    end

    def product_id?(value)
      value.to_s.start_with?("prod_")
    end

    def discount_percent(monthly:, annual:)
      percents = TIERS.filter_map do |tier|
        monthly_cents = monthly.dig(tier, :amount_cents)
        annual_details = annual[tier]
        annual_cents = annual_details&.dig(:amount_cents)
        next unless monthly_cents && annual_cents && monthly_cents.positive?

        effective_monthly = annual_cents / 12.0
        discount = 1 - (effective_monthly / monthly_cents)
        (discount * 100).round
      end

      percents.max
    end

    def format_amount(amount_cents_or_float)
      return nil if amount_cents_or_float.blank?

      dollars = amount_cents_or_float.to_f / 100.0
      format("%.2f", dollars).sub(/\.?0+$/, "")
    end
  end
end
