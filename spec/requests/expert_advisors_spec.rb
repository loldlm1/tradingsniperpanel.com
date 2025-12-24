require "rails_helper"

RSpec.describe "Expert advisor docs", type: :request do
  let(:user) { create(:user) }
  let(:expert_advisor) { create(:expert_advisor, documents: { markdown_en: "docs_eas/sniper_advanced_panel/Manual_EN.md" }) }

  it "renders the Expert Advisors index page" do
    create(:user_expert_advisor, user:, expert_advisor:)
    sign_in user, scope: :user

    get dashboard_expert_advisors_path(locale: :en)

    expect(response).to be_successful
    expect(response.body).to include(expert_advisor.name)
  end

  it "renders docs for an active user EA" do
    create(:user_expert_advisor, user:, expert_advisor:)
    sign_in user, scope: :user

    get dashboard_expert_advisor_docs_path(expert_advisor, locale: :en)

    expect(response).to be_successful
    expect(response.body).to include(expert_advisor.name)
    expect(response.body).to include("Sniper Advanced Panel")
  end

  it "returns not found when user does not own the EA" do
    sign_in user, scope: :user

    get dashboard_expert_advisor_docs_path(expert_advisor, locale: :en)

    expect(response).to have_http_status(:not_found)
  end

  it "orders expert advisors by tier_rank then name" do
    tiered = [
      create(:expert_advisor, name: "Sniper Advanced Panel", tier_rank: 1),
      create(:expert_advisor, name: "Pandora Box", tier_rank: 2),
      create(:expert_advisor, name: "XAU HFT Scalper", tier_rank: 3)
    ]
    sign_in user, scope: :user

    get dashboard_expert_advisors_path(locale: :en)

    positions = tiered.map { |ea| response.body.index(ea.name) }
    expect(positions).to all(be_present)
    expect(positions).to eq(positions.sort)
  end
end
