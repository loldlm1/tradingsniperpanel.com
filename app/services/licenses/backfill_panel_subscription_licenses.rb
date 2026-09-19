module Licenses
  class BackfillPanelSubscriptionLicenses < BackfillSubscriptionLicenses
    def initialize(**options)
      super(**options, ea_id: "sniper_advanced_panel", tiers: Billing::SubscriptionCatalog.tiers)
    end
  end
end
