module Billing
  class PlanComparator
    TIERS = Billing::DashboardPlan::TIERS

    def initialize(pricing_catalog: nil, stripe_fallback: false, logger: Rails.logger)
      @price_amounts = Billing::PriceAmountResolver.new(
        pricing_catalog: pricing_catalog,
        stripe_fallback: stripe_fallback,
        logger: logger
      )
    end

    def compare(current_key:, target_key:, current_price_id: nil, target_price_id: nil)
      return :current if current_key.present? && current_key == target_key

      current_amount = amount_for(current_key, current_price_id)
      target_amount = amount_for(target_key, target_price_id)
      if current_amount && target_amount
        return target_amount > current_amount ? :upgrade : :downgrade
      end

      current_tier, current_interval = parse_price_key(current_key)
      target_tier, target_interval = parse_price_key(target_key)
      return :upgrade if current_tier.blank? || target_tier.blank?

      current_index = TIERS.index(current_tier)
      target_index = TIERS.index(target_tier)
      return :upgrade if current_index.blank? || target_index.blank?

      if target_index > current_index
        :upgrade
      elsif target_index < current_index
        :downgrade
      else
        interval_weight(target_interval) > interval_weight(current_interval) ? :upgrade : :downgrade
      end
    end

    private

    attr_reader :price_amounts

    def amount_for(price_key, price_id)
      amount = price_amounts.amount_cents_for(price_key)
      return amount if amount.present?

      price_amounts.amount_cents_for_price_id(price_id)
    end

    def parse_price_key(price_key)
      parts = price_key.to_s.split("_")
      return [nil, nil] if parts.size < 2

      [parts.first.to_sym, parts.last]
    end

    def interval_weight(interval)
      case interval.to_s
      when "annual"
        2
      when "monthly"
        1
      else
        0
      end
    end
  end
end
