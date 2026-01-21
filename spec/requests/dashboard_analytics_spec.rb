require "rails_helper"

RSpec.describe "Dashboard analytics", type: :request do
  let(:user) { create(:user) }
  let(:expert_advisor) { create(:expert_advisor, name: "Grid Guard") }
  let!(:license) { create(:license, user:, expert_advisor:, status: "active") }
  let!(:broker_accounts) do
    Array.new(12) do |index|
      create(:broker_account,
             license: license,
             company: "PagedFX",
             account_number: 2000 + index,
             account_type: index.even? ? :real : :demo)
    end
  end

  before do
    sign_in user, scope: :user
  end

  it "renders broker PnL analytics with broker accounts" do
    get dashboard_analytics_path

    expect(response).to be_successful
    expect(response.body).to include(I18n.t("dashboard.analytics.cards.daily_performance.title"))
    expect(response.body).to include(I18n.t("dashboard.analytics.cards.active_now.title"))
    expect(response.body).to include("analytics-card-01")
  end

  it "renders analytics cards without pagination" do
    get dashboard_analytics_path

    expect(response).to be_successful
    expect(response.body).to include(I18n.t("dashboard.analytics.cards.top_eas.title"))
    expect(response.body).to include(I18n.t("dashboard.analytics.cards.latest_lessons.title"))
  end
end
