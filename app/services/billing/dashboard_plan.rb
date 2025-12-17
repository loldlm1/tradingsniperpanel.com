module Billing
  class DashboardPlan
    TIERS = %i[basic hft pro].freeze

    def initialize(subscription:)
      @subscription = subscription
    end

    def call
      current_price_id = subscription&.processor_plan
      current_price_key = Billing::PriceKeyResolver.key_for_price_id(current_price_id)
      current_tier = current_price_key&.split("_")&.first&.to_sym

      current_index = current_tier ? TIERS.index(current_tier) : nil
      visible_tiers = current_index ? TIERS.drop(current_index) : TIERS

      {
        current_price_id: current_price_id,
        current_price_key: current_price_key,
        current_tier: current_tier,
        visible_tiers: visible_tiers
      }
    end

    private

    attr_reader :subscription
  end
end

