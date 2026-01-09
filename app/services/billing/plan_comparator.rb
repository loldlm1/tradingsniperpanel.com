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

      current_plan = plan_for_key_or_price(current_key, current_price_id)
      target_plan = plan_for_key_or_price(target_key, target_price_id)
      current_amount = current_plan&.amount_cents || amount_for(current_key, current_price_id)
      target_amount = target_plan&.amount_cents || amount_for(target_key, target_price_id)
      if current_amount && target_amount
        return target_amount > current_amount ? :upgrade : :downgrade
      end

      current_tier = current_plan&.tier
      target_tier = target_plan&.tier
      current_interval = current_plan&.interval
      target_interval = target_plan&.interval

      if current_tier.blank? || target_tier.blank?
        current_tier, current_interval = parse_price_key(current_key)
        target_tier, target_interval = parse_price_key(target_key)
      end
      return :upgrade if current_tier.blank? || target_tier.blank?

      current_index = tier_order.index(current_tier.to_s)
      target_index = tier_order.index(target_tier.to_s)
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

    attr_reader :price_amounts, :pricing_catalog

    def amount_for(price_key, price_id)
      amount = price_amounts.amount_cents_for(price_key)
      return amount if amount.present?

      price_amounts.amount_cents_for_price_id(price_id)
    end

    def plan_for_key_or_price(price_key, price_id)
      BillingPlan.for_key(price_key) || BillingPlan.for_price_id(price_id)
    end

    def parse_price_key(price_key)
      parts = price_key.to_s.split("_")
      return [nil, nil] if parts.size < 2

      [parts.shift.to_sym, parts.join("_")]
    end

    def interval_weight(interval)
      case interval.to_s
      when "annual"
        3
      when "monthly"
        2
      when "year"
        3
      when "month"
        2
      when "week"
        1
      when "day"
        0
      else
        0
      end
    end

    def tier_order
      @tier_order ||= begin
        tiers = pricing_catalog&.dig(:tiers)
        tiers.present? ? tiers.map(&:to_s) : BillingPlan.subscription_tiers.map(&:tier)
      end
    end
  end
end
