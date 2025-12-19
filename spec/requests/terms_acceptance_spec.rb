require "rails_helper"

RSpec.describe "Terms acceptance gate", type: :request do
  it "redirects users without consent to the acceptance page and records consent" do
    user = create(:user, email: "consent@example.com")
    user.update_column(:terms_accepted_at, nil)

    sign_in user

    get dashboard_path
    expect(response).to redirect_to(new_terms_acceptance_path)

    post terms_acceptance_path, params: { accept_terms: "1" }
    expect(response).to redirect_to(dashboard_path)

    user.reload
    expect(user.terms_accepted_at).to be_present
  end
end
