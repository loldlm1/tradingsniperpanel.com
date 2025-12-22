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
    expect(response.body).to include(I18n.t("dashboard.analytics.pnl_title"))
    expect(response.body).to include("PagedFX")
    expect(response.body).to include(I18n.t("dashboard.analytics.top_setups"))
  end

  it "paginates the top setups table" do
    get dashboard_analytics_path(page: 2)

    expect(response).to be_successful
    expect(response.body).to include(I18n.t("dashboard.analytics.page", current: 2, total: 2))
  end
end
