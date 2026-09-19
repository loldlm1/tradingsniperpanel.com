module Licenses
  class BackfillChuSubscriptionLicenses < BackfillSubscriptionLicenses
    def initialize(**options)
      super(**options, ea_id: Billing::ChuSniperPricing::TIER, tiers: [ Billing::PandoraPricing::TIER ])
    end
  end
end
