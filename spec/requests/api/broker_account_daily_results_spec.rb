require "rails_helper"

RSpec.describe "Broker account daily results API", type: :request do
  let(:encoder) { Licenses::LicenseKeyEncoder.new(primary_key: ENV["EA_LICENSE_PRIMARY_KEY"], secondary_key: ENV["EA_LICENSE_SECRET_KEY"]) }
  let(:user) { create(:user, email: "api-user@example.com") }
  let(:expert_advisor) { create(:expert_advisor, ea_id: "ea-api") }
  let(:expires_at) { 5.days.from_now }
  let(:license_key) { encoder.generate(email: user.email, ea_id: expert_advisor.ea_id, expires_at: expires_at) }
  let(:source_id) { ENV.fetch("EA_LICENSE_SOURCE_ID", "trading_sniper_floor") }
  let!(:license) do
    create(
      :license,
      user: user,
      expert_advisor: expert_advisor,
      status: "active",
      trial_ends_at: nil,
      expires_at: expires_at,
      encrypted_key: license_key
    )
  end
  let!(:broker_account) do
    create(:broker_account, license: license, company: "BrokerX", account_number: 9876, account_type: :real)
  end
  let(:timestamp) { Time.utc(2025, 1, 15, 12, 0, 0).to_i }

  it "creates a daily result" do
    params = {
      source: source_id,
      email: user.email,
      ea_id: expert_advisor.ea_id,
      license_key: license_key,
      broker_account: {
        company: broker_account.company,
        account_number: broker_account.account_number,
        account_type: broker_account.account_type
      },
      result_timestamp: timestamp,
      result_value: "10.50"
    }

    expect do
      post "/api/v1/broker_accounts/daily_results", params: params
    end.to change(BrokerAccountDailyResult, :count).by(1)

    expect(response).to have_http_status(:created)
    body = JSON.parse(response.body)
    expect(body["ok"]).to eq(true)
    expect(body["result_on"]).to eq("2025-01-15")
    expect(body["result_value"]).to eq("10.50")
  end

  it "rejects duplicates for the same UTC day" do
    create(:broker_account_daily_result, broker_account: broker_account, result_timestamp: timestamp, result_value: 10.50)

    params = {
      source: source_id,
      email: user.email,
      ea_id: expert_advisor.ea_id,
      license_key: license_key,
      broker_account: {
        company: broker_account.company,
        account_number: broker_account.account_number,
        account_type: broker_account.account_type
      },
      result_timestamp: Time.utc(2025, 1, 15, 23, 0, 0).to_i,
      result_value: "12.00"
    }

    expect do
      post "/api/v1/broker_accounts/daily_results", params: params
    end.not_to change(BrokerAccountDailyResult, :count)

    expect(response).to have_http_status(:conflict)
    body = JSON.parse(response.body)
    expect(body["ok"]).to eq(false)
    expect(body["error"]).to eq("already_recorded")
  end

  it "rejects missing broker accounts" do
    params = {
      source: source_id,
      email: user.email,
      ea_id: expert_advisor.ea_id,
      license_key: license_key,
      broker_account: {
        company: "MissingBroker",
        account_number: 1111,
        account_type: :real
      },
      result_timestamp: timestamp,
      result_value: "9.00"
    }

    expect do
      post "/api/v1/broker_accounts/daily_results", params: params
    end.not_to change(BrokerAccountDailyResult, :count)

    expect(response).to have_http_status(:not_found)
    body = JSON.parse(response.body)
    expect(body["ok"]).to eq(false)
    expect(body["error"]).to eq("broker_account_not_found")
  end

  it "rejects invalid timestamps" do
    params = {
      source: source_id,
      email: user.email,
      ea_id: expert_advisor.ea_id,
      license_key: license_key,
      broker_account: {
        company: broker_account.company,
        account_number: broker_account.account_number,
        account_type: broker_account.account_type
      },
      result_timestamp: "not-a-time",
      result_value: "9.00"
    }

    expect do
      post "/api/v1/broker_accounts/daily_results", params: params
    end.not_to change(BrokerAccountDailyResult, :count)

    expect(response).to have_http_status(:unprocessable_content)
    body = JSON.parse(response.body)
    expect(body["ok"]).to eq(false)
    expect(body["error"]).to eq("invalid_payload")
  end
end
