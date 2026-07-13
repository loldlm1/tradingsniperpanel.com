require "rails_helper"

RSpec.describe "Home pricing CTAs", type: :request do
  around do |example|
    original_template = ENV["LANDING_TEMPLATE"]
    Marketing::LandingTemplate.reset!
    ENV["LANDING_TEMPLATE"] = "neon"

    example.run
  ensure
    ENV["LANDING_TEMPLATE"] = original_template
    Marketing::LandingTemplate.reset!
  end

  before do
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
  end

  it "shows only Pandora monthly and annual checkout choices" do
    create(:billing_plan, tier: "basic", key: "basic_monthly")

    get root_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(Billing::PandoraPricing::MONTHLY_KEY)
    expect(response.body).to include(Billing::PandoraPricing::ANNUAL_KEY)
    expect(response.body).to include("79.00")
    expect(response.body).to include("616.20")
    expect(response.body).to include(I18n.t("dashboard.plans.toggle.save_up_to", percent: 35, locale: :en))
    expect(response.body).not_to include("basic_monthly")
    expect(response.body).not_to include("one-time marketplace")
    expect(response.body).to include("x-bind:href")
  end

  it "selects only canonical Pandora interval hints" do
    get root_path(price_key: Billing::PandoraPricing::ANNUAL_KEY)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("x-data=\"{ period: 'annual' }\"")

    get root_path(price_key: "basic_annual")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("x-data=\"{ period: 'monthly' }\"")
  end

  it "does not show a dashboard promotion modal on home even when an active promotion exists" do
    create(:promotion_code, :active, code: "MARCH25")

    get root_path

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("dashboard-discount-modal")
    expect(response.body).not_to include("MARCH25")
  end
end
