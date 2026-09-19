require "rails_helper"

RSpec.describe "Panel companion licensing", type: :request do
  let!(:catalog) { create_subscription_catalog }
  let(:user) { create(:user, :admin) }
  let(:panel) { catalog.fetch(:expert_advisors).fetch("sniper_advanced_panel") }
  let(:chu) { catalog.fetch(:expert_advisors).fetch("chu_sniper_trailing") }
  let!(:grant) { create(:manual_subscription, user: user, billing_plan: catalog.fetch(:chu_monthly)) }
  let(:panel_license) { License.find_by!(user: user, expert_advisor: panel) }
  let(:chu_license) { License.find_by!(user: user, expert_advisor: chu) }

  before { Licenses::ManualSubscriptionSync.new(manual_subscription_id: grant.id).call }

  it "accepts each tool's own key and assigns distinct trading magic on the same broker account" do
    verify_license(chu_license)
    expect(response).to have_http_status(:ok)
    chu_magic = response.parsed_body.fetch("magic_number")

    verify_license(panel_license)
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.fetch("magic_number")).not_to eq(chu_magic)
    expect(response.parsed_body.fetch("expires_at")).to eq(grant.ends_at.to_i)
    expect(response.parsed_body.fetch("granted_addons")).to eq([])

    verify_license(panel_license, key: chu_license.encrypted_key)
    expect(response).to have_http_status(:unauthorized)
    expect(response.parsed_body.fetch("error")).to eq("invalid_key")
  end

  it "rejects the Panel key after the shared manual entitlement is revoked" do
    key = panel_license.encrypted_key
    grant.update!(status: "cancelled")
    Licenses::ManualSubscriptionSync.new(manual_subscription_id: grant.id).call

    verify_license(panel_license.reload, key: key)

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body.fetch("error")).to eq("expired")
    expect(chu_license).to be_expired
  end

  it "shares the five subscription seats across Chu and Panel sessions" do
    [ chu_license, panel_license, panel_license, chu_license, panel_license ].each_with_index do |license, index|
      verify_license(license, account_number: 1000 + index)
      expect(response).to have_http_status(:ok)
    end

    verify_license(panel_license, account_number: 2000)

    expect(response).not_to have_http_status(:ok)
    expect(response.parsed_body.fetch("error")).to eq("online_limit_reached")
    expect(LicenseOnlineSession.where(user: user).count).to eq(5)
  end

  it "does not accept another user's Panel key" do
    other = create(:user)
    other_grant = create(:manual_subscription, user: other, billing_plan: catalog.fetch(:chu_monthly))
    Licenses::ManualSubscriptionSync.new(manual_subscription_id: other_grant.id).call
    other_license = License.find_by!(user: other, expert_advisor: panel)

    verify_license(panel_license, key: other_license.encrypted_key)

    expect(response).to have_http_status(:unauthorized)
    expect(response.parsed_body.fetch("error")).to eq("invalid_key")
  end

  def verify_license(license, key: license.encrypted_key, account_number: 1000)
    post "/api/v1/licenses/verify", params: {
      source: ENV.fetch("EA_LICENSE_SOURCE_ID", "trading_sniper_floor"),
      email: user.email,
      ea_id: license.expert_advisor.ea_id,
      license_key: key,
      broker_account: { company: "CompanionTestBroker", account_number: account_number, account_type: "demo" }
    }, as: :json
  end
end
