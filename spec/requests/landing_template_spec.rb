require "rails_helper"

RSpec.describe "Landing template selection", type: :request do
  around do |example|
    original_template = ENV["LANDING_TEMPLATE"]
    Marketing::LandingTemplate.reset!
    example.run
  ensure
    ENV["LANDING_TEMPLATE"] = original_template
    Marketing::LandingTemplate.reset!
  end

  it "renders the default template" do
    ENV["LANDING_TEMPLATE"] = nil
    Marketing::LandingTemplate.reset!

    get root_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to match(%r{/assets/neon/images/hero-illustration})
  end

  it "renders the fintech template when selected" do
    ENV["LANDING_TEMPLATE"] = "fintech"
    Marketing::LandingTemplate.reset!

    get root_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to match(%r{/assets/fintech/images/hero_oficial})
  end

  it "falls back to neon and logs when template is invalid" do
    ENV["LANDING_TEMPLATE"] = "unknown-template"
    Marketing::LandingTemplate.reset!

    allow(Rails.logger).to receive(:warn)

    get root_path

    expect(Rails.logger).to have_received(:warn).with(/LANDING_TEMPLATE/).at_least(:once)
    expect(response.body).to match(%r{/assets/neon/images/hero-illustration})
  end
end
