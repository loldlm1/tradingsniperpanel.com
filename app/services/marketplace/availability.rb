module Marketplace
  class Availability
    def initialize(scope: MarketplaceProduct)
      @scope = scope
    end

    def call
      scope.active
           .joins(:billing_plan)
           .merge(BillingPlan.one_time.active)
           .exists?
    rescue StandardError => e
      Rails.logger.warn("[Marketplace::Availability] failed: #{e.class} - #{e.message}")
      false
    end

    private

    attr_reader :scope
  end
end
