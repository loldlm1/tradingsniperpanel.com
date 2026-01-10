module Billing
  class PlanComparator
    def initialize(pricing_catalog: nil, stripe_fallback: false, logger: Rails.logger)
      @price_amounts = Billing::PriceAmountResolver.new(
        pricing_catalog: pricing_catalog,
        stripe_fallback: stripe_fallback,
        logger: logger
      )
      @pricing_catalog = pricing_catalog
    end

    def compare(current_key:, target_key:, current_price_id: nil, target_price_id: nil)
      return :current if current_key.present? && current_key == target_key

      current_plan = BillingPlan.for_key(current_key) || BillingPlan.for_price_id(current_price_id)
      target_plan = BillingPlan.for_key(target_key) || BillingPlan.for_price_id(target_price_id)
      current_amount = current_plan&.amount_cents || amount_for(current_key, current_price_id)
      target_amount = target_plan&.amount_cents || amount_for(target_key, target_price_id)

      return :upgrade if current_amount.blank? || target_amount.blank?

      target_amount.to_i >= current_amount.to_i ? :upgrade : :downgrade
    end

    private

    attr_reader :price_amounts, :pricing_catalog

    def amount_for(price_key, price_id)
      amount = price_amounts.amount_cents_for(price_key)
      return amount if amount.present?

      price_amounts.amount_cents_for_price_id(price_id)
    end
  end
end
