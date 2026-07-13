require "rails_helper"

RSpec.describe Marketing::NeonLandingPricing do
  it "presents one Pandora product with exact monthly and annual intervals" do
    create(:billing_plan, tier: "basic", key: "basic_monthly")
    create(
      :billing_plan,
      tier: Billing::PandoraPricing::TIER,
      key: Billing::PandoraPricing::MONTHLY_KEY,
      amount_cents: Billing::PandoraPricing::MONTHLY_CENTS
    )
    create(
      :billing_plan,
      :annual,
      tier: Billing::PandoraPricing::TIER,
      key: Billing::PandoraPricing::ANNUAL_KEY,
      amount_cents: Billing::PandoraPricing::ANNUAL_CENTS
    )

    pricing = described_class.new.call

    expect(pricing.fetch(:tiers).map { |tier| tier[:key] }).to eq([ Billing::PandoraPricing::TIER ])
    expect(pricing.fetch(:intervals).map { |interval| interval[:key] }).to eq(%w[monthly annual])
    expect(pricing.dig(:prices, "monthly", "pandora_pro", :display)).to eq("79.00")
    expect(pricing.dig(:prices, "annual", "pandora_pro", :display)).to eq("616.20")
    expect(pricing[:discount_percent]).to eq(35)
    expect(pricing.dig(:tiers, 0, :features)).to include(
      I18n.t("licenses.online_seats.subscription_feature", count: 5, locale: I18n.locale)
    )
  end
end
