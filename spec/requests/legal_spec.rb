require "rails_helper"

RSpec.describe "Legal pages", type: :request do
  let(:user) { create(:user) }

  it "renders terms and privacy for guests" do
    get terms_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(I18n.t("legal.terms.title"))

    get privacy_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(I18n.t("legal.privacy.title"))
  end

  it "does not redirect signed-in users from terms and privacy" do
    sign_in user, scope: :user

    get terms_path
    expect(response).to have_http_status(:ok)

    get privacy_path
    expect(response).to have_http_status(:ok)
  end
end

