require "omniauth"

OmniAuth.config.test_mode = true

module OmniauthHelpers
  def mock_google_oauth(email: "google.user@example.com", uid: "google-uid-123", name: "Google User")
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: uid,
      info: {
        email: email,
        name: name
      }
    )
  end

  def reset_mock_auth
    OmniAuth.config.mock_auth[:google_oauth2] = nil
  end
end

RSpec.configure do |config|
  config.include OmniauthHelpers

  config.after do
    reset_mock_auth
  end
end
