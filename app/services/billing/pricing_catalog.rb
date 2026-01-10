require "digest"

module Billing
  class PricingCatalog
    CACHE_VERSION = 2

    def call
      plans = BillingPlan.subscription.active
      return {} if plans.empty?

      cache_key = "billing/pricing_catalog/v#{CACHE_VERSION}/#{Digest::SHA256.hexdigest(cache_signature(plans))}"
      Rails.cache.fetch(cache_key, expires_in: 12.hours) do
        build_catalog(plans)
      end
    end

    private

    def build_catalog(plans)
      tiers = tiers_for(plans)
      intervals = intervals_for(plans)
      prices = prices_for(plans, intervals)

      {
        tiers: tiers,
        intervals: intervals,
        prices: prices,
        discount_percent: discount_percent(prices)
      }
    rescue StandardError => e
      Rails.logger.error("Billing::PricingCatalog failed: #{e.class} - #{e.message}")
      {}
    end

    def cache_signature(plans)
      plans.order(:id).pluck(:id, :updated_at).map { |id, ts| "#{id}-#{ts.to_i}" }.join(":")
    end

    def tiers_for(plans)
      grouped = plans.where.not(tier: nil).group_by(&:tier)
      grouped.keys.sort_by do |tier|
        tier_plans = grouped[tier]
        min_sort = tier_plans.map(&:sort_order).min.to_i
        min_price = tier_plans.map { |plan| plan.amount_cents.to_i }.min
        [min_sort, min_price || 0, tier.to_s]
      end
    end

    def intervals_for(plans)
      pairs = plans.map { |plan| [plan.interval, plan.interval_count] }.uniq
      sorted = pairs.sort_by { |interval, count| Billing::IntervalLabeler.sort_key(interval:, interval_count: count) }

      sorted.map do |interval, count|
        interval_key = Billing::IntervalLabeler.interval_key(interval:, interval_count: count)
        uses_effective_monthly = interval.to_s == "year" && count.to_i == 1
        per_label = Billing::IntervalLabeler.per_label(interval:, interval_count: count)
        per_label = Billing::IntervalLabeler.per_label(interval: "month", interval_count: 1) if uses_effective_monthly
        {
          key: interval_key,
          interval: interval,
          interval_count: count,
          label: Billing::IntervalLabeler.label(interval:, interval_count: count),
          billed_label: Billing::IntervalLabeler.billed_label(interval:, interval_count: count),
          per_label: per_label,
          uses_effective_monthly: uses_effective_monthly
        }
      end
    end

    def prices_for(plans, intervals)
      prices = intervals.each_with_object({}) do |interval, memo|
        key = interval[:key]
        memo[key] = {} if key.present?
      end

      plans.each do |plan|
        next if plan.tier.blank?

        interval_key = plan.interval_key
        next if interval_key.blank? || !prices.key?(interval_key)

        prices[interval_key][plan.tier] = price_details(plan)
      end

      prices
    end

    def price_details(plan)
      effective_monthly_cents = effective_monthly_cents(plan)
      {
        amount_cents: plan.amount_cents,
        currency: plan.currency,
        display: format_amount(plan.amount_cents),
        effective_monthly_cents: effective_monthly_cents,
        effective_monthly_display: format_amount(effective_monthly_cents),
        plan_key: plan.key
      }
    end

    def effective_monthly_cents(plan)
      return unless plan.subscription?

      count = plan.interval_count.to_i
      return if count <= 0

      case plan.interval
      when "year"
        plan.amount_cents.to_f / (12 * count)
      when "month"
        plan.amount_cents.to_f / count
      end
    end

    def discount_percent(prices)
      monthly_key = Billing::IntervalLabeler.interval_key(interval: "month", interval_count: 1)
      annual_key = Billing::IntervalLabeler.interval_key(interval: "year", interval_count: 1)

      percents = prices.fetch(annual_key, {}).filter_map do |tier, annual|
        monthly = prices.fetch(monthly_key, {})[tier]
        next unless monthly && annual
        next unless monthly[:amount_cents].to_i.positive?

        effective_monthly = annual[:amount_cents].to_f / 12.0
        discount = 1 - (effective_monthly / monthly[:amount_cents].to_f)
        (discount * 100).round
      end

      percents.max
    end

    def format_amount(amount_cents_or_float)
      return nil if amount_cents_or_float.blank?

      dollars = amount_cents_or_float.to_f / 100.0
      format("%.2f", dollars).sub(/\.?0+$/, "")
    end

    def self.filter_intervals(intervals:, prices:, tiers:)
      return [] if intervals.blank?
      return intervals if tiers.blank?

      tier_keys = Array(tiers).map(&:to_s)
      intervals.select do |interval|
        interval_key = interval[:key]
        tier_keys.all? { |tier| prices.dig(interval_key, tier).present? }
      end
    end

    def self.filter_prices(prices:, intervals:, tiers:)
      return {} if prices.blank? || intervals.blank?

      tier_keys = Array(tiers).map(&:to_s)
      interval_keys = intervals.map { |interval| interval[:key] }

      interval_keys.each_with_object({}) do |interval_key, memo|
        tier_prices = prices[interval_key] || {}
        memo[interval_key] = tier_keys.each_with_object({}) do |tier, tier_memo|
          value = tier_prices[tier]
          tier_memo[tier] = value if value.present?
        end
      end
    end
  end
end
