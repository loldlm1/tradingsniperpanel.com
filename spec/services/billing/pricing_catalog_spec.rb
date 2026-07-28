require "rails_helper"

RSpec.describe Billing::PricingCatalog do
  let(:service) { described_class.new }

  it "builds complete Chu and Pandora monthly and annual catalogs" do
    create(:billing_plan, tier: "basic", key: "basic_monthly", amount_cents: 2_000)
    create_catalog(Billing::ChuSniperPricing)
    create_catalog(Billing::PandoraPricing)

    catalog = service.call

    expect(catalog[:tiers]).to eq([ Billing::ChuSniperPricing::TIER, Billing::PandoraPricing::TIER ])
    expect(catalog.fetch(:intervals).map { |interval| interval[:key] }).to eq(%w[monthly annual])
    expect(catalog.dig(:prices, "monthly", "chu_sniper_trailing", :display)).to eq("19.99")
    expect(catalog.dig(:prices, "annual", "chu_sniper_trailing", :display)).to eq("155.92")
    expect(catalog.dig(:prices, "annual", "chu_sniper_trailing", :effective_monthly_display)).to eq("12.99")
    expect(catalog.dig(:prices, "monthly", "pandora_pro", :display)).to eq("79.00")
    expect(catalog.dig(:prices, "annual", "pandora_pro", :display)).to eq("616.20")
    expect(catalog.dig(:prices, "annual", "pandora_pro", :effective_monthly_display)).to eq("51.35")
    expect(catalog.dig(:prices, "monthly", "pandora_pro", :stripe_price_id)).to be_present
    expect(catalog[:discount_percent]).to eq(35)
  end

  it "keeps a complete product visible when another product is incomplete" do
    create_catalog(Billing::PandoraPricing)
    create_chu_plan(:monthly)

    catalog = service.call

    expect(catalog[:tiers]).to eq([ Billing::PandoraPricing::TIER ])
    expect(catalog.dig(:prices, "monthly", "pandora_pro")).to be_present
    expect(catalog.dig(:prices, "monthly", "chu_sniper_trailing")).to be_nil
  end

  it "returns no catalog until at least one complete product pair is available" do
    create_chu_plan(:monthly)

    expect(service.call).to eq({})

    create_chu_plan(:annual, amount_cents: 77_992)
    expect(service.call).to eq({})
  end

  def create_catalog(pricing)
    create_plan(pricing, :monthly)
    create_plan(pricing, :annual)
  end

  def create_chu_plan(interval, amount_cents: nil)
    create_plan(Billing::ChuSniperPricing, interval, amount_cents: amount_cents)
  end

  def create_plan(pricing, interval, amount_cents: nil)
    annual = interval == :annual
    create(
      :billing_plan,
      *(annual ? [ :annual ] : []),
      tier: pricing::TIER,
      key: annual ? pricing::ANNUAL_KEY : pricing::MONTHLY_KEY,
      amount_cents: amount_cents || (annual ? pricing::ANNUAL_CENTS : pricing::MONTHLY_CENTS),
      metadata: { "catalog_product" => pricing::PRODUCT_NAME.parameterize(separator: "_") }
    )
  end
end
