require "rails_helper"

RSpec.describe "Expert advisor docs", type: :request do
  let(:user) { create(:user) }
  let(:expert_advisor) { create(:expert_advisor, documents: { manual: "/docs/sniper_advanced_panel/Manual_EN.md" }) }

  it "renders docs for an active user EA" do
    create(:user_expert_advisor, user:, expert_advisor:)
    sign_in user, scope: :user

    get dashboard_expert_advisor_docs_path(expert_advisor, locale: :en)

    expect(response).to be_successful
    expect(response.body).to include(expert_advisor.name)
    expect(response.body).to include("/docs/sniper_advanced_panel/Manual_EN.md")
  end

  it "returns not found when user does not own the EA" do
    sign_in user, scope: :user

    get dashboard_expert_advisor_docs_path(expert_advisor, locale: :en)

    expect(response).to have_http_status(:not_found)
  end
end
