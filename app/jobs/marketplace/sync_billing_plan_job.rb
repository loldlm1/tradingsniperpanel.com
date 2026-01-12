module Marketplace
  class SyncBillingPlanJob < ApplicationJob
    queue_as :default

    retry_on StandardError, wait: 5.seconds, attempts: 3

    def perform(marketplace_product_id)
      product = MarketplaceProduct.find_by(id: marketplace_product_id)
      return unless product

      Marketplace::PlanSync.new(product: product).call
    end
  end
end
