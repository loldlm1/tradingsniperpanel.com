module Billing
  class DashboardPlan
    def initialize(subscription:, pricing_catalog: nil)
      @subscription = subscription
      @pricing_catalog = pricing_catalog
    end

    def call
      current_price_id = subscription&.processor_plan
      current_plan = BillingPlan.for_price_id(current_price_id)
      current_price_key = current_plan&.key || Billing::PriceKeyResolver.key_for_price_id(current_price_id)
      current_tier = current_plan&.tier
      current_interval_key = current_plan&.interval_key
      current_interval_label = current_plan&.interval_label
      scheduled_change = resolve_scheduled_change(current_price_key)
      tiers = visible_tiers
      intervals = pricing_intervals

      {
        current_price_id: current_price_id,
        current_price_key: current_price_key,
        current_tier: current_tier,
        current_interval_key: current_interval_key,
        current_interval_label: current_interval_label,
        visible_tiers: tiers,
        intervals: intervals,
        scheduled_change: scheduled_change,
        states: build_states(current_price_key, tiers, intervals)
      }
    end

    private

    attr_reader :subscription, :pricing_catalog

    def build_states(current_price_key, tiers, intervals)
      return {} if current_price_key.blank? || tiers.blank? || intervals.blank?

      interval_keys = intervals.map { |interval| interval[:key] }
      tiers.index_with do |tier|
        interval_keys.index_with do |interval_key|
          state_for("#{tier}_#{interval_key}", current_price_key)
        end
      end
    end

    def state_for(target_key, current_key)
      return :current if target_key == current_key

      comparator.compare(
        current_key: current_key,
        target_key: target_key
      )
    end

    def comparator
      @comparator ||= Billing::PlanComparator.new(pricing_catalog: pricing_catalog, stripe_fallback: false)
    end

    def resolve_scheduled_change(current_price_key)
      change = Billing::ScheduledPlanChange.new(subscription: subscription).fetch(current_price_key: current_price_key)
      return nil if change.blank?

      plan = BillingPlan.for_key(change[:price_key])
      tier = plan&.tier
      interval_key = plan&.interval_key
      interval_label = plan&.interval_label

      if tier.blank? || interval_key.blank?
        tier, interval_key = parse_price_key(change[:price_key])
      end

      change.merge(tier: tier, interval_key: interval_key, interval_label: interval_label)
    end

    def parse_price_key(price_key)
      parts = price_key.to_s.split("_")
      return [nil, nil] if parts.size < 2

      [parts.shift.to_s, parts.join("_")]
    end

    def visible_tiers
      tiers = pricing_catalog&.dig(:tiers)
      return tiers if tiers.present?

      BillingPlan.subscription_tiers.map(&:tier)
    end

    def pricing_intervals
      intervals = pricing_catalog&.dig(:intervals)
      return intervals if intervals.present?

      Billing::PricingCatalog.new.call[:intervals] || []
    end
  end
end
