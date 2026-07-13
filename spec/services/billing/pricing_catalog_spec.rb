require "rails_helper"

RSpec.describe Billing::PricingCatalog do
  let(:service) { described_class.new }

  it "builds only the complete Pandora monthly and annual catalog" do
    create(:billing_plan, tier: "basic", key: "basic_monthly", amount_cents: 2_000)
    create_pandora_catalog

    catalog = service.call

    expect(catalog[:tiers]).to eq([ Billing::PandoraPricing::TIER ])
    expect(catalog.fetch(:intervals).map { |interval| interval[:key] }).to eq(%w[monthly annual])
    expect(catalog.dig(:prices, "monthly", "pandora_pro", :display)).to eq("79.00")
    expect(catalog.dig(:prices, "annual", "pandora_pro", :display)).to eq("616.20")
    expect(catalog.dig(:prices, "annual", "pandora_pro", :effective_monthly_display)).to eq("51.35")
    expect(catalog.dig(:prices, "monthly", "pandora_pro", :stripe_price_id)).to be_present
    expect(catalog[:discount_percent]).to eq(35)
  end

  it "returns no catalog until both exact current prices are available" do
    create_pandora_plan(:monthly)

    expect(service.call).to eq({})

    create_pandora_plan(:annual, amount_cents: 77_992)
    expect(service.call).to eq({})
  end

  def create_pandora_catalog
    create_pandora_plan(:monthly)
    create_pandora_plan(:annual)
  end

  def create_pandora_plan(interval, amount_cents: nil)
    annual = interval == :annual
    create(
      :billing_plan,
      *(annual ? [ :annual ] : []),
      tier: Billing::PandoraPricing::TIER,
      key: annual ? Billing::PandoraPricing::ANNUAL_KEY : Billing::PandoraPricing::MONTHLY_KEY,
      amount_cents: amount_cents || (annual ? Billing::PandoraPricing::ANNUAL_CENTS : Billing::PandoraPricing::MONTHLY_CENTS)
    )
  end
end
