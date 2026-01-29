module Dashboard
  class SidebarMarketplaceProducts
    def initialize(limit: 5, active_slug: nil, scope: MarketplaceProduct)
      @limit = limit
      @active_slug = active_slug.to_s.presence
      @scope = scope
    end

    def call
      list = Marketplace::SidebarProducts.new(limit: limit, scope: scope).call.to_a
      return list unless active_slug

      active_product = scope.active.find_by(slug: active_slug)
      return list unless active_product
      return list if list.any? { |product| product.id == active_product.id }

      list + [active_product]
    end

    private

    attr_reader :limit, :active_slug, :scope
  end
end
