require "rails_helper"

RSpec.describe Billing::ChuSniperPricing do
  it "defines the confirmed Chu subscription prices" do
    expect(described_class::TIER).to eq("chu_sniper_trailing")
    expect(described_class::MONTHLY_CENTS).to eq(1_999)
    expect(described_class::ANNUAL_DISCOUNT_PERCENT).to eq(35)
    expect(described_class::ANNUAL_CENTS).to eq(15_592)
    expect(described_class::ANNUAL_CENTS).to eq(
      described_class::MONTHLY_CENTS * 12 * 65 / 100
    )
    expect(described_class::PLAN_KEYS).to eq(%w[chu_sniper_trailing_monthly chu_sniper_trailing_annual])
  end
end
