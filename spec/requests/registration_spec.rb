require "rails_helper"

RSpec.describe "User registration", type: :request do
  it "permits preferred_locale and saves it on sign up" do
    post user_registration_path(locale: :es), params: {
      user: {
        email: "signup@example.com",
        password: "password123",
        password_confirmation: "password123",
        preferred_locale: "es"
      }
    }

    user = User.find_by(email: "signup@example.com")
    expect(response).to redirect_to(root_path(locale: :es))
    expect(user).to be_present
    expect(user.preferred_locale).to eq("es")
  end
end
