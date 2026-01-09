require "rails_helper"

RSpec.describe Billing::PricingCatalog do
  let(:service) { described_class.new }

  it "builds intervals and prices from billing plans" do
    create(:billing_plan, tier: "basic", key: "basic_monthly", interval: "month", interval_count: 1, amount_cents: 2000)
    create(:billing_plan, tier: "basic", key: "basic_annual", interval: "year", interval_count: 1, amount_cents: 18_000)

    catalog = service.call

    interval_keys = catalog.fetch(:intervals, []).map { |interval| interval[:key] }
    expect(interval_keys).to include("monthly", "annual")
    expect(catalog.dig(:prices, "monthly", "basic", :display)).to eq("20")
    expect(catalog.dig(:prices, "annual", "basic", :effective_monthly_display)).to eq("15")
    expect(catalog[:discount_percent]).to eq(25)
  end
end
