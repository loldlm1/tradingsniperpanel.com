require "rails_helper"

RSpec.describe Billing::PricingCatalog do
  let(:service) { described_class.new }

  it "builds intervals and prices from billing plans" do
    create(:billing_plan, tier: "basic", key: "basic_monthly", interval: "month", interval_count: 1, amount_cents: 2000)
    create(:billing_plan, tier: "basic", key: "basic_annual", interval: "year", interval_count: 1, amount_cents: 18_000)

    catalog = service.call

    interval_keys = catalog.fetch(:intervals, []).map { |interval| interval[:key] }
    expect(interval_keys).to include("monthly", "annual")
    expect(catalog.dig(:prices, "monthly", "basic", :display)).to eq("20.00")
    expect(catalog.dig(:prices, "annual", "basic", :effective_monthly_display)).to eq("15.00")
    expect(catalog[:discount_percent]).to eq(25)
  end

  it "uses exact Pandora monthly and annual pricing without floats" do
    create(
      :billing_plan,
      tier: Billing::PandoraPricing::TIER,
      key: "pandora_pro_monthly",
      interval: "month",
      interval_count: 1,
      amount_cents: Billing::PandoraPricing::MONTHLY_CENTS
    )
    create(
      :billing_plan,
      tier: Billing::PandoraPricing::TIER,
      key: "pandora_pro_annual",
      interval: "year",
      interval_count: 1,
      amount_cents: Billing::PandoraPricing::ANNUAL_CENTS
    )

    catalog = service.call

    expect(catalog.dig(:prices, "monthly", "pandora_pro", :display)).to eq("79.00")
    expect(catalog.dig(:prices, "annual", "pandora_pro", :display)).to eq("616.20")
    expect(catalog.dig(:prices, "annual", "pandora_pro", :effective_monthly_display)).to eq("51.35")
    expect(catalog[:discount_percent]).to eq(35)
  end
end
