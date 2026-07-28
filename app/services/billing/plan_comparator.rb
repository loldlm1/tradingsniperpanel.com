module Billing
  class PlanComparator
    INTERVAL_RANKS = {
      "daily" => 1,
      "weekly" => 2,
      "monthly" => 3,
      "annual" => 4
    }.freeze

    def initialize(pricing_catalog: nil, stripe_fallback: false, logger: Rails.logger)
      @price_amounts = Billing::PriceAmountResolver.new(
        pricing_catalog: pricing_catalog,
        stripe_fallback: stripe_fallback,
        logger: logger
      )
      @pricing_catalog = pricing_catalog
    end

    def compare(current_key:, target_key:, current_price_id: nil, target_price_id: nil)
      same_caller_key = current_key.present? && current_key == target_key

      current_descriptor = descriptor_for(current_key, current_price_id)
      target_descriptor = descriptor_for(target_key, target_price_id)

      if current_descriptor[:rank] && target_descriptor[:rank]
        access_comparison = current_descriptor[:rank][0] <=> target_descriptor[:rank][0]
        return direction_for(access_comparison) unless access_comparison.zero?

        interval_comparison = current_descriptor[:rank][1] <=> target_descriptor[:rank][1]
        return direction_for(interval_comparison) unless interval_comparison.zero?

        return :current
      end

      return :current if same_caller_key

      current_plan = current_descriptor[:plan]
      target_plan = target_descriptor[:plan]
      current_amount = current_plan&.amount_cents || amount_for(current_key, current_price_id)
      target_amount = target_plan&.amount_cents || amount_for(target_key, target_price_id)

      return :upgrade if current_amount.blank? || target_amount.blank?

      target_amount.to_i >= current_amount.to_i ? :upgrade : :downgrade
    end

    # Returns the comparable catalog rank for presentation code that needs to
    # orient a cross-product change without looking at raw charge amounts.
    def rank_for(key, price_id: nil)
      descriptor_for(key, price_id)[:rank]
    end

    private

    attr_reader :price_amounts, :pricing_catalog

    def descriptor_for(key, price_id)
      plan = Billing::SubscriptionCatalog.resolve_plan(plan_key: key, price_id: price_id)
      parsed = Billing::SubscriptionCatalog.parse_plan_key(plan&.key || key)
      tier = plan&.tier.presence || parsed[:tier]
      product = Billing::SubscriptionCatalog.product_for_tier(tier)
      interval_key = plan&.interval_key.presence || parsed[:interval_key]
      interval_rank = INTERVAL_RANKS[interval_key.to_s]
      rank = if product&.access_rank && interval_rank
        [ product.access_rank, interval_rank ]
      end

      { plan: plan, rank: rank }
    end

    def direction_for(comparison)
      comparison.negative? ? :upgrade : :downgrade
    end

    def amount_for(price_key, price_id)
      amount = price_amounts.amount_cents_for(price_key)
      return amount if amount.present?

      price_amounts.amount_cents_for_price_id(price_id)
    end
  end
end
