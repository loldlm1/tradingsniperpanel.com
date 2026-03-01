require "rails_helper"

RSpec.describe Marketing::NeonLandingPricing do
  it "caps tiers to the first three and filters intervals with missing prices" do
    create(:billing_plan, tier: "basic", key: "basic_monthly", interval: "month", interval_count: 1, sort_order: 1)
    create(:billing_plan, tier: "basic", key: "basic_annual", interval: "year", interval_count: 1, sort_order: 1)
    create(:billing_plan, tier: "hft", key: "hft_monthly", interval: "month", interval_count: 1, sort_order: 2)
    create(:billing_plan, tier: "hft", key: "hft_annual", interval: "year", interval_count: 1, sort_order: 2)
    create(:billing_plan, tier: "pro", key: "pro_monthly", interval: "month", interval_count: 1, sort_order: 3)
    create(:billing_plan, tier: "elite", key: "elite_monthly", interval: "month", interval_count: 1, sort_order: 4)

    pricing = described_class.new.call

    tier_keys = pricing.fetch(:tiers, []).map { |tier| tier[:key] }
    interval_keys = pricing.fetch(:intervals, []).map { |interval| interval[:key] }

    expect(tier_keys).to eq(%w[basic hft pro])
    expect(interval_keys).to eq(["monthly"])
    expect(pricing.dig(:prices, "monthly").keys).to match_array(%w[basic hft pro])
    expect(pricing.dig(:tiers, 0, :features)).to include(
      I18n.t("licenses.online_seats.subscription_feature", count: 5, locale: I18n.locale)
    )
  end
end
