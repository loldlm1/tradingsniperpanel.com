module Billing
  module PandoraPricing
    TIER = "pandora_pro".freeze
    CURRENCY = "usd".freeze
    MONTHLY_CENTS = 7_900
    ANNUAL_DISCOUNT_PERCENT = 35
    ANNUAL_CENTS = MONTHLY_CENTS * 12 * (100 - ANNUAL_DISCOUNT_PERCENT) / 100
  end
end
