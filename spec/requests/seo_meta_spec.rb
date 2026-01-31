require "rails_helper"

RSpec.describe "SEO meta tags", type: :request do
  around do |example|
    original_template = ENV["LANDING_TEMPLATE"]
    ENV["LANDING_TEMPLATE"] = "neon"
    Marketing::LandingTemplate.reset!
    example.run
    ENV["LANDING_TEMPLATE"] = original_template
    Marketing::LandingTemplate.reset!
  end

  it "uses the neon hero subtitle for the home meta description" do
    get "/"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(%(meta name="description" content="#{I18n.t("landing.neon.hero.subtitle")}"))
  end

  it "uses legal subtitles for legal meta descriptions" do
    get "/terms"
    expect(response.body).to include(%(meta name="description" content="#{I18n.t("legal.terms.subtitle")}"))

    get "/privacy"
    expect(response.body).to include(%(meta name="description" content="#{I18n.t("legal.privacy.subtitle")}"))

    get "/refunds-and-cancellations"
    expect(response.body).to include(%(meta name="description" content="#{I18n.t("legal.refunds_and_cancellations.subtitle")}"))
  end
end
