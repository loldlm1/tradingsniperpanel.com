require "rails_helper"

RSpec.describe Marketing::NeonLandingPricing do
  it "presents both complete products with exact monthly and annual intervals" do
    create_subscription_catalog

    pricing = described_class.new.call

    expect(pricing.fetch(:tiers).map { |tier| tier[:key] }).to eq(
      [ Billing::ChuSniperPricing::TIER, Billing::PandoraPricing::TIER ]
    )
    expect(pricing.fetch(:intervals).map { |interval| interval[:key] }).to eq(%w[monthly annual])
    expect(pricing.dig(:prices, "monthly", "chu_sniper_trailing", :display)).to eq("19.99")
    expect(pricing.dig(:prices, "annual", "chu_sniper_trailing", :display)).to eq("155.92")
    expect(pricing.dig(:prices, "monthly", "pandora_pro", :display)).to eq("79.00")
    expect(pricing.dig(:prices, "annual", "pandora_pro", :display)).to eq("616.20")
    expect(pricing[:discount_percent]).to eq(35)
    expect(pricing.dig(:tiers, 0, :features)).to include(
      I18n.t("landing.neon.pricing.tiers.chu_sniper_trailing.features", locale: I18n.locale).first,
      I18n.t("licenses.online_seats.subscription_feature", count: 5, locale: I18n.locale)
    )
    expect(pricing.dig(:tiers, 0, :featured)).to be(false)
    expect(pricing.dig(:tiers, 1, :featured)).to be(true)
  end

  it "keeps a complete Pandora card when Chu is missing an interval" do
    catalog = create_subscription_catalog
    catalog.fetch(:chu_annual).update!(active: false)

    pricing = described_class.new.call

    expect(pricing.fetch(:tiers).map { |tier| tier[:key] }).to eq([ Billing::PandoraPricing::TIER ])
    expect(pricing.dig(:prices, "monthly", Billing::PandoraPricing::TIER, :display)).to eq("79.00")
    expect(pricing.dig(:prices, "monthly", Billing::ChuSniperPricing::TIER)).to be_nil
  end
end
