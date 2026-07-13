require "rails_helper"

RSpec.describe Billing::PandoraPricing do
  it "defines the exact Pandora subscription prices" do
    expect(described_class::TIER).to eq("pandora_pro")
    expect(described_class::MONTHLY_CENTS).to eq(7_900)
    expect(described_class::ANNUAL_DISCOUNT_PERCENT).to eq(35)
    expect(described_class::ANNUAL_CENTS).to eq(61_620)
    expect(described_class::ANNUAL_CENTS).to eq(
      described_class::MONTHLY_CENTS * 12 * 65 / 100
    )
    expect(described_class::PLAN_KEYS).to eq(%w[pandora_pro_monthly pandora_pro_annual])
    expect(described_class::PLAN_DEFINITIONS.fetch(described_class::MONTHLY_KEY)).to include(
      interval: "month",
      interval_count: 1,
      amount_cents: 7_900
    )
  end
end
