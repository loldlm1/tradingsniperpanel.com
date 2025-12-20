require "rails_helper"

RSpec.describe "Licenses API", type: :request do
  let(:encoder) { Licenses::LicenseKeyEncoder.new(primary_key: ENV["EA_LICENSE_PRIMARY_KEY"], secondary_key: ENV["EA_LICENSE_SECRET_KEY"]) }
  let(:user) { create(:user, email: "api-user@example.com") }
  let(:expert_advisor) { create(:expert_advisor, ea_id: "ea-api") }
  let(:license_key) { encoder.generate(email: user.email, ea_id: expert_advisor.ea_id) }
  let!(:license) do
    create(
      :license,
      user:,
      expert_advisor:,
      status: "active",
      trial_ends_at: nil,
      expires_at: 5.days.from_now,
      encrypted_key: license_key
    )
  end

  it "returns ok for valid payload" do
    post "/api/v1/licenses/verify", params: {
      source: "trading_sniper_ea",
      email: user.email,
      ea_id: expert_advisor.ea_id,
      license_key: license_key
    }

    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body["ok"]).to eq(true)
    expect(body["trial"]).to eq(false)
  end

  it "rejects invalid sources" do
    post "/api/v1/licenses/verify", params: {
      source: "bad_source",
      email: user.email,
      ea_id: expert_advisor.ea_id,
      license_key: license_key
    }

    expect(response).to have_http_status(:unauthorized)
    body = JSON.parse(response.body)
    expect(body["ok"]).to eq(false)
    expect(body["error"]).to eq("invalid_source")
  end

  it "creates or reuses broker accounts from payload" do
    params = {
      source: "trading_sniper_ea",
      email: user.email,
      ea_id: expert_advisor.ea_id,
      license_key: license_key,
      broker_account: {
        name: "Account A",
        company: "BrokerX",
        account_number: 9876,
        account_type: :real
      }
    }

    expect do
      post "/api/v1/licenses/verify", params: params
    end.to change(BrokerAccount, :count).by(1)

    body = JSON.parse(response.body)
    expect(body["broker_account"]["company"]).to eq("BrokerX")
    expect(body["broker_account"]["account_number"]).to eq(9876)

    expect do
      post "/api/v1/licenses/verify", params: params.merge(broker_account: params[:broker_account].merge(name: "Updated Name"))
    end.not_to change(BrokerAccount, :count)

    expect(BrokerAccount.first.name).to eq("Account A")
  end
end
