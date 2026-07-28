require "rails_helper"

RSpec.describe Billing::PlanComparator do
  subject(:comparator) { described_class.new(stripe_fallback: false) }

  let!(:catalog) { create_subscription_catalog }

  it "compares the complete canonical transition matrix by access rank and interval" do
    expected = {
      Billing::ChuSniperPricing::MONTHLY_KEY => {
        Billing::ChuSniperPricing::MONTHLY_KEY => :current,
        Billing::ChuSniperPricing::ANNUAL_KEY => :upgrade,
        Billing::PandoraPricing::MONTHLY_KEY => :upgrade,
        Billing::PandoraPricing::ANNUAL_KEY => :upgrade
      },
      Billing::ChuSniperPricing::ANNUAL_KEY => {
        Billing::ChuSniperPricing::MONTHLY_KEY => :downgrade,
        Billing::ChuSniperPricing::ANNUAL_KEY => :current,
        Billing::PandoraPricing::MONTHLY_KEY => :upgrade,
        Billing::PandoraPricing::ANNUAL_KEY => :upgrade
      },
      Billing::PandoraPricing::MONTHLY_KEY => {
        Billing::ChuSniperPricing::MONTHLY_KEY => :downgrade,
        Billing::ChuSniperPricing::ANNUAL_KEY => :downgrade,
        Billing::PandoraPricing::MONTHLY_KEY => :current,
        Billing::PandoraPricing::ANNUAL_KEY => :upgrade
      },
      Billing::PandoraPricing::ANNUAL_KEY => {
        Billing::ChuSniperPricing::MONTHLY_KEY => :downgrade,
        Billing::ChuSniperPricing::ANNUAL_KEY => :downgrade,
        Billing::PandoraPricing::MONTHLY_KEY => :downgrade,
        Billing::PandoraPricing::ANNUAL_KEY => :current
      }
    }

    expected.each do |current_key, targets|
      targets.each do |target_key, direction|
        expect(comparator.compare(current_key: current_key, target_key: target_key)).to eq(direction)
      end
    end
  end

  it "prefers persisted price references over conflicting caller keys" do
    result = comparator.compare(
      current_key: Billing::PandoraPricing::ANNUAL_KEY,
      target_key: Billing::ChuSniperPricing::MONTHLY_KEY,
      current_price_id: catalog[:chu_monthly].stripe_price_id,
      target_price_id: catalog[:pandora_monthly].stripe_price_id
    )

    expect(result).to eq(:upgrade)
  end

  it "does not let equal caller keys override conflicting persisted prices" do
    result = comparator.compare(
      current_key: Billing::PandoraPricing::MONTHLY_KEY,
      target_key: Billing::PandoraPricing::MONTHLY_KEY,
      current_price_id: catalog[:chu_monthly].stripe_price_id,
      target_price_id: catalog[:pandora_monthly].stripe_price_id
    )

    expect(result).to eq(:upgrade)
  end

  it "retains amount comparison and safe-upgrade fallback for unknown legacy plans" do
    legacy_current = create(:billing_plan, tier: "legacy_a", key: "legacy_a_monthly", amount_cents: 2000)
    legacy_target = create(:billing_plan, tier: "legacy_b", key: "legacy_b_monthly", amount_cents: 1000)

    expect(comparator.compare(current_key: legacy_current.key, target_key: legacy_target.key)).to eq(:downgrade)
    expect(comparator.compare(current_key: "missing_monthly", target_key: "unknown_monthly")).to eq(:upgrade)
  end
end
