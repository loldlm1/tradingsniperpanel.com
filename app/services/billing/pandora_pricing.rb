module Billing
  module PandoraPricing
    TIER = "pandora_pro".freeze
    CURRENCY = "usd".freeze
    MONTHLY_CENTS = 7_900
    ANNUAL_DISCOUNT_PERCENT = 35
    ANNUAL_CENTS = MONTHLY_CENTS * 12 * (100 - ANNUAL_DISCOUNT_PERCENT) / 100
    MONTHLY_KEY = "#{TIER}_monthly".freeze
    ANNUAL_KEY = "#{TIER}_annual".freeze
    PLAN_KEYS = [ MONTHLY_KEY, ANNUAL_KEY ].freeze
    PLAN_DEFINITIONS = {
      MONTHLY_KEY => { interval: "month", interval_count: 1, amount_cents: MONTHLY_CENTS }.freeze,
      ANNUAL_KEY => { interval: "year", interval_count: 1, amount_cents: ANNUAL_CENTS }.freeze
    }.freeze
  end
end
