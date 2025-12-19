require "rails_helper"

RSpec.describe "User registration", type: :request do
  it "saves preferred_locale and terms acceptance on sign up" do
    post user_registration_path(locale: :es), params: {
      user: {
        email: "signup@example.com",
        password: "password123",
        password_confirmation: "password123",
        terms_of_service: "1"
      }
    }

    user = User.find_by(email: "signup@example.com")
    expect(response).to redirect_to(dashboard_path(locale: :es))
    expect(user).to be_present
    expect(user.preferred_locale).to eq("es")
    expect(user.terms_accepted_at).to be_present
  end

  it "requires terms acceptance" do
    post user_registration_path(locale: :en), params: {
      user: {
        email: "no_terms@example.com",
        password: "password123",
        password_confirmation: "password123"
      }
    }

    expect(response).to have_http_status(:unprocessable_content)
    expect(User.find_by(email: "no_terms@example.com")).to be_nil
  end
end
