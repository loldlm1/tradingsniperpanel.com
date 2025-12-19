require "rails_helper"

RSpec.describe "Google OAuth", type: :request do
  let(:callback_path) { user_google_oauth2_omniauth_callback_path }

  it "creates a new user with terms accepted and signs in" do
    mock_google_oauth(email: "oauth-new@example.com", uid: "oauth-uid-1", name: "OAuth New")

    get callback_path

    user = User.find_by(email: "oauth-new@example.com")
    expect(user).to be_present
    expect(user.provider).to eq("google_oauth2")
    expect(user.uid).to eq("oauth-uid-1")
    expect(user.terms_accepted_at).to be_present
    expect(user.role).to eq("trader")
    expect(response).to redirect_to(dashboard_path)
  end

  it "links an existing user without a provider and keeps terms for re-consent" do
    user = create(:user, email: "oauth-existing@example.com")
    user.update_column(:terms_accepted_at, nil)

    mock_google_oauth(email: "oauth-existing@example.com", uid: "oauth-uid-2", name: "Existing User")

    get callback_path
    expect(response).to redirect_to(dashboard_path)

    follow_redirect!
    expect(response).to redirect_to(new_terms_acceptance_path)

    user.reload
    expect(user.provider).to eq("google_oauth2")
    expect(user.uid).to eq("oauth-uid-2")
    expect(user.terms_accepted_at).to be_nil
  end

  it "redirects to sign in on failure" do
    OmniAuth.config.mock_auth[:google_oauth2] = :invalid_credentials

    get callback_path

    expect(response).to redirect_to(new_user_session_path)
  end
end
