module Marketplace
  class SidebarProducts
    def initialize(limit: 5, scope: MarketplaceProduct)
      @limit = limit
      @scope = scope
    end

    def call
      scope.active
           .joins(:billing_plan)
           .merge(BillingPlan.active)
           .left_joins(billing_plan: :marketplace_purchases)
           .group("marketplace_products.id")
           .order(Arel.sql("COUNT(marketplace_purchases.id) DESC"), created_at: :desc)
           .limit(limit)
    end

    private

    attr_reader :limit, :scope
  end
end
