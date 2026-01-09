module Marketing
  class NeonLandingPricing
    def call
      Billing::PricingCatalog.new.call
    end
  end
end
