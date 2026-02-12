require "rails_helper"

RSpec.describe "Plan persistence across auth", type: :request do
  shared_examples "plan persistence" do |price_key|
    it "redirects to dashboard plans with the selected plan after signup" do
      get new_user_registration_path(locale: :en, price_key:)
      expect(cookies["desired_plan"]).to be_present

      post user_registration_path(locale: :en), params: {
        user: {
          email: "newuser@example.com",
          password: "password123",
          password_confirmation: "password123",
          terms_of_service: "1"
        }
      }

      expect(response).to redirect_to(dashboard_plans_path(locale: :en, price_key:))
    end
  end

  include_examples "plan persistence", "basic_monthly"
  include_examples "plan persistence", "pro_annual"

  it "parses underscore-tier plan keys and silently falls back to default intervals" do
    create(:billing_plan, tier: "basic", key: "basic_monthly", interval: "month", interval_count: 1, amount_cents: 2000)
    create(:billing_plan, :annual, tier: "basic", key: "basic_annual", amount_cents: 18_000)
    create(:billing_plan, tier: "pandora_pro", key: "pandora_pro_monthly", interval: "month", interval_count: 1, amount_cents: 3000)
    create(:billing_plan, :annual, tier: "pandora_pro", key: "pandora_pro_annual", amount_cents: 27_000)

    user = create(:user)
    sign_in user, scope: :user

    get dashboard_plans_path(locale: :en, price_key: "pandora_pro_annual")

    expect(response).to be_successful
    expect(response.body).to include("x-data=\"{ period: 'annual' }\"")
    expect(response.body).to include(I18n.t("dashboard.plans.requested_plan", locale: :en))

    get dashboard_plans_path(locale: :en, price_key: "pandora_pro_invalid")

    expect(response).to be_successful
    expect(response.body).to include("x-data=\"{ period: 'monthly' }\"")
  end
end
