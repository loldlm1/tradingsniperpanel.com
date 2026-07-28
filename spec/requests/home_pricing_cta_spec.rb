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
    create_subscription_catalog
  end

  it "shows Chu and Pandora monthly and annual checkout choices" do
    create(:billing_plan, tier: "basic", key: "basic_monthly")

    get root_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(Billing::ChuSniperPricing::MONTHLY_KEY)
    expect(response.body).to include(Billing::ChuSniperPricing::ANNUAL_KEY)
    expect(response.body).to include(Billing::PandoraPricing::MONTHLY_KEY)
    expect(response.body).to include(Billing::PandoraPricing::ANNUAL_KEY)
    expect(response.body).to include("19.99")
    expect(response.body).to include("155.92")
    expect(response.body).to include("79.00")
    expect(response.body).to include("616.20")
    expect(response.body).to include(I18n.t("dashboard.plans.toggle.save_up_to", percent: 35, locale: :en))
    expect(response.body).not_to include("basic_monthly")
    expect(response.body).not_to include("one-time marketplace")
    expect(response.body).to include(I18n.t("landing.neon.pricing.tiers.chu_sniper_trailing.cta", locale: :en))
    expect(response.body).to include(I18n.t("landing.neon.pricing.tiers.pandora_pro.cta", locale: :en))
    expect(response.body).to include("x-bind:href")
  end

  it "selects the interval for every canonical product hint" do
    Billing::SubscriptionCatalog.plan_keys.each do |price_key|
      get root_path(price_key: price_key)

      expect(response).to have_http_status(:ok)
      interval = Billing::SubscriptionCatalog.parse_plan_key(price_key).fetch(:interval_key)
      expect(response.body).to include("x-data=\"{ period: '#{interval}' }\"")
    end

    get root_path(price_key: "basic_annual")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("x-data=\"{ period: 'monthly' }\"")
  end

  it "renders both product cards in English and Spanish" do
    { en: [ "Chu Sniper Trailing", "Pandora Box" ], es: [ "Chu Sniper Trailing", "Pandora Box" ] }.each do |locale, names|
      get root_path(locale: locale)

      expect(response).to have_http_status(:ok)
      names.each { |name| expect(response.body).to include(name) }
      expect(response.body).to include(I18n.t("landing.neon.pricing.tiers.chu_sniper_trailing.features", locale: locale).first)
      expect(response.body).to include(I18n.t("landing.neon.cta.title", locale: locale))
    end
  end

  it "does not show a dashboard promotion modal on home even when an active promotion exists" do
    create(:promotion_code, :active, code: "MARCH25")

    get root_path

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("dashboard-discount-modal")
    expect(response.body).not_to include("MARCH25")
  end
end
