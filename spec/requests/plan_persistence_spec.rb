require "rails_helper"

RSpec.describe "Plan persistence across auth", type: :request do
  shared_examples "plan persistence" do |price_key|
    it "redirects to dashboard pricing with the selected plan after signup" do
      get new_user_registration_path(locale: :en, price_key:)
      expect(cookies["desired_plan"]).to be_present

      post user_registration_path(locale: :en), params: {
        user: {
          email: "newuser@example.com",
          password: "password123",
          password_confirmation: "password123"
        }
      }

      expect(response).to redirect_to(dashboard_pricing_path(locale: :en, price_key:))
    end
  end

  include_examples "plan persistence", "basic_monthly"
  include_examples "plan persistence", "pro_annual"
end
