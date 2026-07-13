require "rails_helper"

RSpec.describe "Landing template locale and branding", type: :request do
  TEMPLATE_EXPECTATIONS = {
    "neon" => "Pandora Box EA for MetaTrader 5",
    "fintech" => "Execution playbooks"
  }.freeze

  around do |example|
    original_template = ENV["LANDING_TEMPLATE"]
    branding = Rails.configuration.x.branding
    original_branding = {
      app_name: branding.app_name,
      short_name: branding.short_name,
      support_email: branding.support_email
    }
    original_mailer_sender = Devise.mailer_sender
    original_locale = I18n.locale

    branding.app_name = "QA Brand"
    branding.short_name = "QA Short"
    branding.support_email = "qa@example.com"
    Devise.mailer_sender = branding.support_email

    example.run
  ensure
    ENV["LANDING_TEMPLATE"] = original_template
    Marketing::LandingTemplate.reset!
    Devise.mailer_sender = original_mailer_sender
    branding.app_name = original_branding[:app_name]
    branding.short_name = original_branding[:short_name]
    branding.support_email = original_branding[:support_email]
    I18n.locale = original_locale
  end

  it "renders English copy and app title for each landing template" do
    TEMPLATE_EXPECTATIONS.each do |template, expected_copy|
      ENV["LANDING_TEMPLATE"] = template
      Marketing::LandingTemplate.reset!

      get root_path(locale: :en)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('<html lang="en">')
      expect(response.body).to include(expected_copy)
      expect(response.body).to include("<title>QA Brand</title>")
    end
  end

  it "uses app short name on the dashboard regardless of template" do
    user = create(:user)
    sign_in user, scope: :user

    TEMPLATE_EXPECTATIONS.keys.each do |template|
      ENV["LANDING_TEMPLATE"] = template
      Marketing::LandingTemplate.reset!

      get dashboard_path(locale: :en)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("<title>QA Short Dashboard</title>")
    end
  end

  it "uses support email as the Devise mailer sender" do
    TEMPLATE_EXPECTATIONS.keys.each do |template|
      ENV["LANDING_TEMPLATE"] = template
      Marketing::LandingTemplate.reset!

      expect(Devise.mailer_sender).to eq("qa@example.com")
    end
  end
end
