require "rails_helper"

RSpec.describe "Licenses Instance Magic API", type: :request do
  let(:encoder) { Licenses::LicenseKeyEncoder.new(primary_key: ENV["EA_LICENSE_PRIMARY_KEY"], secondary_key: ENV["EA_LICENSE_SECRET_KEY"]) }
  let(:user) { create(:user, email: "instance-user@example.com") }
  let(:expert_advisor) do
    create(:expert_advisor, ea_id: "chu_sniper_trailing", ea_type: :ea_tool, trial_enabled: false)
  end
  let(:expires_at) { 5.days.from_now }
  let(:token_version) { 2 }
  let(:license_key) do
    encoder.generate(
      email: user.email,
      ea_id: expert_advisor.ea_id,
      expires_at: expires_at,
      token_version: token_version
    )
  end
  let(:source_id) { ENV.fetch("EA_LICENSE_SOURCE_ID", "trading_sniper_floor") }
  let(:broker_account_payload) do
    {
      company: "BrokerX",
      account_number: 9876,
      account_type: "real"
    }
  end
  let!(:license) do
    create(
      :license,
      user: user,
      expert_advisor: expert_advisor,
      status: "active",
      token_version: token_version,
      trial_ends_at: nil,
      expires_at: expires_at,
      encrypted_key: license_key
    )
  end
  let!(:broker_account) do
    create(
      :broker_account,
      license: license,
      company: broker_account_payload.fetch(:company),
      account_number: broker_account_payload.fetch(:account_number),
      account_type: broker_account_payload.fetch(:account_type)
    )
  end
  let!(:online_session) do
    create(
      :license_online_session,
      user: user,
      expert_advisor: expert_advisor,
      company: broker_account_payload.fetch(:company),
      account_number: broker_account_payload.fetch(:account_number),
      account_type: broker_account_payload.fetch(:account_type),
      entitlement_source: "one_time",
      last_seen_at: 1.minute.ago
    )
  end

  it "allocates instance magic for a valid active lane without mutating online seats" do
    original_last_seen_at = online_session.last_seen_at

    expect do
      post "/api/v1/licenses/instance_magic", params: instance_magic_params
    end.to change(LicenseInstanceMagicNumber, :count).by(1)
      .and change(LicenseOnlineSession, :count).by(0)

    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body["ok"]).to eq(true)
    expect(body["instance_id"]).to eq("chu_sniper_trailing_ABC123")
    expect(body["magic_number"]).to be > 0
    expect(body["magic_number"]).to be <= Licenses::MagicNumberPolicy::MAX_VALUE
    expect(body["trade_identity_scope"]).to eq("instance")
    expect(online_session.reload.last_seen_at.to_i).to eq(original_last_seen_at.to_i)
  end

  it "returns stable magic for the same instance id" do
    post "/api/v1/licenses/instance_magic", params: instance_magic_params
    first_magic = JSON.parse(response.body).fetch("magic_number")

    post "/api/v1/licenses/instance_magic", params: instance_magic_params(instance_id: " chu_sniper_trailing_ABC123 ")
    second_magic = JSON.parse(response.body).fetch("magic_number")

    expect(first_magic).to eq(second_magic)
    expect(LicenseInstanceMagicNumber.count).to eq(1)
  end

  it "returns different magic for a different instance id on the same broker account" do
    post "/api/v1/licenses/instance_magic", params: instance_magic_params(instance_id: "chu_sniper_trailing_A")
    first_magic = JSON.parse(response.body).fetch("magic_number")

    post "/api/v1/licenses/instance_magic", params: instance_magic_params(instance_id: "chu_sniper_trailing_B")
    second_magic = JSON.parse(response.body).fetch("magic_number")

    expect(first_magic).not_to eq(second_magic)
    expect(LicenseInstanceMagicNumber.count).to eq(2)
  end

  it "rejects invalid license identity" do
    post "/api/v1/licenses/instance_magic", params: instance_magic_params(source: "bad_source")

    expect(response).to have_http_status(:unauthorized)
    body = JSON.parse(response.body)
    expect(body["ok"]).to eq(false)
    expect(body["error"]).to eq("invalid_source")
  end

  it "rejects missing broker accounts" do
    post "/api/v1/licenses/instance_magic", params: instance_magic_params(
      broker_account: broker_account_payload.merge(company: "MissingBroker", account_number: 1111)
    )

    expect(response).to have_http_status(:not_found)
    body = JSON.parse(response.body)
    expect(body["ok"]).to eq(false)
    expect(body["error"]).to eq("broker_account_not_found")
  end

  it "rejects missing and invalid instance ids" do
    post "/api/v1/licenses/instance_magic", params: instance_magic_params.except(:instance_id)

    expect(response).to have_http_status(:unprocessable_content)
    body = JSON.parse(response.body)
    expect(body["error"]).to eq("missing_instance_id")

    post "/api/v1/licenses/instance_magic", params: instance_magic_params(instance_id: "bad value!")

    expect(response).to have_http_status(:unprocessable_content)
    body = JSON.parse(response.body)
    expect(body["error"]).to eq("invalid_instance_id")
  end

  it "requires a current active lane session" do
    online_session.update!(last_seen_at: Licenses::OnlineSeatAllocator::DEFAULT_TTL_SECONDS.seconds.ago - 1.second)

    expect do
      post "/api/v1/licenses/instance_magic", params: instance_magic_params
    end.not_to change(LicenseInstanceMagicNumber, :count)

    expect(response).to have_http_status(:conflict)
    body = JSON.parse(response.body)
    expect(body["ok"]).to eq(false)
    expect(body["error"]).to eq("lane_session_required")
  end

  it "uses a separate rate limit bucket" do
    allow(Rails.cache).to receive(:increment).and_call_original
    allow(Rails.cache).to receive(:increment)
      .with("licenses/instance_magic/#{user.email}", 1, expires_in: 1.minute)
      .and_return(61)

    post "/api/v1/licenses/instance_magic", params: instance_magic_params

    expect(response).to have_http_status(:too_many_requests)
    body = JSON.parse(response.body)
    expect(body["ok"]).to eq(false)
    expect(body["error"]).to eq("rate_limited")
  end

  def instance_magic_params(overrides = {})
    {
      source: source_id,
      email: user.email,
      ea_id: expert_advisor.ea_id,
      license_key: license_key,
      broker_account: broker_account_payload,
      instance_id: "chu_sniper_trailing_ABC123"
    }.deep_merge(overrides)
  end
end
