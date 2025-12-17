require "rails_helper"

RSpec.describe "Legal pages", type: :request do
  let(:user) { create(:user) }

  it "renders terms and privacy for guests" do
    get terms_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(I18n.t("legal.terms.title"))
    first_terms_section = Array(I18n.t("legal.terms.sections", default: [])).first&.with_indifferent_access
    first_terms_paragraph = Array(first_terms_section&.dig(:paragraphs)).first
    expect(response.body).to include(first_terms_paragraph) if first_terms_paragraph.present?

    get privacy_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(I18n.t("legal.privacy.title"))
    first_privacy_section = Array(I18n.t("legal.privacy.sections", default: [])).first&.with_indifferent_access
    first_privacy_paragraph = Array(first_privacy_section&.dig(:paragraphs)).first
    expect(response.body).to include(first_privacy_paragraph) if first_privacy_paragraph.present?
  end

  it "does not redirect signed-in users from terms and privacy" do
    sign_in user, scope: :user

    get terms_path
    expect(response).to have_http_status(:ok)

    get privacy_path
    expect(response).to have_http_status(:ok)
  end
end
