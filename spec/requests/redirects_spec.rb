require "rails_helper"

RSpec.describe "Authenticated redirects", type: :request do
  let(:user) { create(:user) }

  it "redirects signed-in users from home to dashboard" do
    sign_in user, scope: :user

    get root_path

    expect(response).to redirect_to(dashboard_path)
  end

  it "redirects signed-in users from pricing to dashboard plans" do
    sign_in user, scope: :user

    get pricing_path

    expect(response).to redirect_to(dashboard_plans_path)
  end
end
