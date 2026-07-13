require "rails_helper"

RSpec.describe "Plan persistence across auth", type: :request do
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

  include_examples "plan persistence", Billing::PandoraPricing::MONTHLY_KEY
  include_examples "plan persistence", Billing::PandoraPricing::ANNUAL_KEY

  it "does not persist retired or unknown plan hints" do
    get new_user_registration_path(locale: :en, price_key: "basic_monthly")

    expect(cookies["desired_plan"]).to be_blank
  end

  it "renders the one Pandora card and silently falls back for invalid hints" do
    create(:billing_plan, tier: "basic", key: "basic_monthly", amount_cents: 2_000)
    user = create(:user)
    sign_in user, scope: :user

    get dashboard_plans_path(locale: :en, price_key: Billing::PandoraPricing::ANNUAL_KEY)

    expect(response).to be_successful
    expect(response.body).to include("x-data=\"{ period: 'annual' }\"")
    expect(response.body).to include(I18n.t("dashboard.plans.requested_plan", locale: :en))
    expect(response.body).to include("79.00")
    expect(response.body).to include("616.20")
    expect(response.body).not_to include("basic_monthly")

    get dashboard_plans_path(locale: :en, price_key: "pandora_pro_invalid")

    expect(response).to be_successful
    expect(response.body).to include("x-data=\"{ period: 'monthly' }\"")
  end
end
