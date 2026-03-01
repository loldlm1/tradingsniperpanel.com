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

  it "includes both monthly and annual price keys so selections persist" do
    %w[basic hft pro].each do |tier|
      create(:billing_plan, tier: tier, key: "#{tier}_monthly", interval: "month", interval_count: 1)
      create(:billing_plan, tier: tier, key: "#{tier}_annual", interval: "year", interval_count: 1)
    end

    get root_path

    expect(response).to have_http_status(:ok)

    %w[basic hft pro].each do |tier|
      expect(response.body).to include("#{tier}_monthly")
      expect(response.body).to include("#{tier}_annual")
    end

    expect(response.body).to include(I18n.t("licenses.online_seats.subscription_feature", count: 5, locale: :en))
    expect(response.body).to include("x-bind:href")
  end

  it "detects interval suffixes for underscore-tier price keys" do
    create(:billing_plan, tier: "basic", key: "basic_monthly", interval: "month", interval_count: 1)
    create(:billing_plan, tier: "basic", key: "basic_annual", interval: "year", interval_count: 1)
    create(:billing_plan, tier: "pandora_pro", key: "pandora_pro_monthly", interval: "month", interval_count: 1)
    create(:billing_plan, tier: "pandora_pro", key: "pandora_pro_annual", interval: "year", interval_count: 1)

    get root_path(price_key: "pandora_pro_annual")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("x-data=\"{ period: 'annual' }\"")

    get root_path(price_key: "pandora_pro_invalid")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("x-data=\"{ period: 'monthly' }\"")
  end
end
