module Billing
  class DashboardPlan
    TIERS = %i[basic hft pro].freeze

    def initialize(subscription:, pricing_catalog: nil)
      @subscription = subscription
      @pricing_catalog = pricing_catalog
    end

    def call
      current_price_id = subscription&.processor_plan
      current_price_key = Billing::PriceKeyResolver.key_for_price_id(current_price_id)
      current_tier, current_interval = parse_price_key(current_price_key)
      scheduled_change = resolve_scheduled_change(current_price_key)

      {
        current_price_id: current_price_id,
        current_price_key: current_price_key,
        current_tier: current_tier,
        current_interval: current_interval,
        visible_tiers: TIERS,
        scheduled_change: scheduled_change,
        states: build_states(current_price_key)
      }
    end

    private

    attr_reader :subscription, :pricing_catalog

    def build_states(current_price_key)
      return {} if current_price_key.blank?

      TIERS.index_with do |tier|
        {
          monthly: state_for("#{tier}_monthly", current_price_key),
          annual: state_for("#{tier}_annual", current_price_key)
        }
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

      tier, interval = parse_price_key(change[:price_key])
      change.merge(tier: tier, interval: interval)
    end

    def parse_price_key(price_key)
      parts = price_key.to_s.split("_")
      return [nil, nil] if parts.size < 2

      [parts.first.to_sym, parts.last]
    end
  end
end
