require "rails_helper"

RSpec.describe "Auth template fallback", type: :request do
  around do |example|
    original_template = ENV["LANDING_TEMPLATE"]
    Marketing::LandingTemplate.reset!
    example.run
  ensure
    ENV["LANDING_TEMPLATE"] = original_template
    Marketing::LandingTemplate.reset!
  end

  it "renders landing auth views when available" do
    ENV["LANDING_TEMPLATE"] = "neon"
    Marketing::LandingTemplate.reset!

    get new_user_session_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("/assets/neon/images/auth-illustration")

    get new_user_registration_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("/assets/neon/images/auth-illustration")

    get new_user_password_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("/assets/neon/images/auth-illustration")
  end

  it "falls back to mosaic auth views when landing auth views are missing" do
    ENV["LANDING_TEMPLATE"] = "fintech"
    Marketing::LandingTemplate.reset!

    get new_user_session_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("/assets/mosaic/images/auth-image")

    get new_user_registration_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("/assets/mosaic/images/auth-image")

    get new_user_password_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("/assets/mosaic/images/auth-image")
  end
end
