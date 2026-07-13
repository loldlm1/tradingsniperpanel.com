require "rails_helper"

RSpec.describe Licenses::OnlineSeatCopy do
  it "builds subscription seat copy from the purchasable Pandora catalog" do
    create(:billing_plan, tier: "basic", key: "basic_monthly", sort_order: 1)
    create(
      :billing_plan,
      tier: Billing::PandoraPricing::TIER,
      key: Billing::PandoraPricing::MONTHLY_KEY,
      amount_cents: Billing::PandoraPricing::MONTHLY_CENTS,
      sort_order: 2
    )

    pandora_copy = described_class.subscription_feature_for_tier(Billing::PandoraPricing::TIER, locale: :en)

    expect(pandora_copy).to eq(I18n.t("licenses.online_seats.subscription_feature", count: 5, locale: :en))
    expect(described_class.subscription_feature_for_tier("basic", locale: :en)).to be_nil
  end

  it "returns nil for tiers that are not in the active subscription order" do
    create(
      :billing_plan,
      tier: Billing::PandoraPricing::TIER,
      key: Billing::PandoraPricing::MONTHLY_KEY,
      amount_cents: Billing::PandoraPricing::MONTHLY_CENTS
    )

    expect(described_class.subscription_feature_for_tier("enterprise", locale: :en)).to be_nil
  end

  it "builds one-time seat copy from the fixed cap constant" do
    expect(described_class.one_time_feature(locale: :en)).to eq(
      I18n.t("licenses.online_seats.one_time_feature", count: 8, locale: :en)
    )
  end
end
