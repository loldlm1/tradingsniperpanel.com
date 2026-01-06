require "rails_helper"

RSpec.describe "Branding", type: :request do
  around do |example|
    branding = Rails.configuration.x.branding
    original = {
      app_name: branding.app_name,
      short_name: branding.short_name,
      support_email: branding.support_email
    }

    branding.app_name = "QA Brand"
    branding.short_name = "QA Short"
    branding.support_email = "qa@example.com"

    example.run
  ensure
    branding.app_name = original[:app_name]
    branding.short_name = original[:short_name]
    branding.support_email = original[:support_email]
  end

  it "renders app_name in the marketing title" do
    get root_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("<title>QA Brand</title>")
  end

  it "renders app_short_name in the dashboard title" do
    user = create(:user)
    sign_in user, scope: :user

    get dashboard_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("<title>QA Short Dashboard</title>")
  end
end
