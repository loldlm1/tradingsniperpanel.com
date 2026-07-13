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
  end
end
