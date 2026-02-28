require "rails_helper"
require "securerandom"

RSpec.describe "Licenses Heartbeat API", type: :request do
  let(:encoder) { Licenses::LicenseKeyEncoder.new(primary_key: ENV["EA_LICENSE_PRIMARY_KEY"], secondary_key: ENV["EA_LICENSE_SECRET_KEY"]) }
  let(:user) { create(:user, email: "hb-user@example.com") }
  let(:expert_advisor) { create(:expert_advisor, ea_id: "ea-heartbeat") }
  let(:expires_at) { 7.days.from_now }
  let(:license_key) { encoder.generate(email: user.email, ea_id: expert_advisor.ea_id, expires_at: expires_at) }
  let(:source_id) { ENV.fetch("EA_LICENSE_SOURCE_ID", "trading_sniper_floor") }
  let(:broker_account_payload) do
    {
      company: "BrokerHB",
      account_number: 111_222,
      account_type: "real"
    }
  end

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

  it "creates or refreshes online session on heartbeat" do
    expect do
      post "/api/v1/licenses/heartbeat", params: heartbeat_params
    end.to change(LicenseOnlineSession, :count).by(1)

    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body["ok"]).to eq(true)
    expect(body["expires_at"]).to eq(expires_at.to_i)

    expect do
      post "/api/v1/licenses/heartbeat", params: heartbeat_params
    end.not_to change(LicenseOnlineSession, :count)
  end

  it "rejects heartbeat payloads without broker identity" do
    post "/api/v1/licenses/heartbeat", params: heartbeat_params.except(:broker_account)

    expect(response).to have_http_status(:unprocessable_content)
    body = JSON.parse(response.body)
    expect(body["error"]).to eq("invalid_payload")
  end

  it "returns online_limit_reached when subscription seats are exhausted" do
    plan = create(
      :billing_plan,
      tier: "basic",
      key: "basic_monthly",
      interval: "month",
      interval_count: 1,
      sort_order: 1,
      stripe_price_id: "price_heartbeat_basic"
    )
    create_pay_subscription(user: user, plan: plan)

    5.times do |idx|
      create(
        :license_online_session,
        user: user,
        expert_advisor: (idx.even? ? expert_advisor : create(:expert_advisor, ea_id: "ea-hb-#{idx}")),
        company: "filled#{idx}",
        account_number: 8000 + idx,
        account_type: "real",
        entitlement_source: "subscription",
        last_seen_at: Time.current
      )
    end

    post "/api/v1/licenses/heartbeat", params: heartbeat_params(
      broker_account: broker_account_payload.merge(company: "OverflowHB", account_number: 9999)
    )

    expect(response).to have_http_status(:too_many_requests)
    body = JSON.parse(response.body)
    expect(body["error"]).to eq("online_limit_reached")
    expect(body["subscription_cap"]).to eq(5)
  end

  def heartbeat_params(overrides = {})
    {
      source: source_id,
      email: user.email,
      ea_id: expert_advisor.ea_id,
      license_key: license_key,
      broker_account: broker_account_payload
    }.deep_merge(overrides)
  end

  def create_pay_subscription(user:, plan:)
    customer = user.pay_customers.create!(
      processor: "stripe",
      processor_id: "cus_#{SecureRandom.hex(4)}",
      default: true
    )

    customer.subscriptions.create!(
      name: "default",
      processor_id: "sub_#{SecureRandom.hex(4)}",
      processor_plan: plan.stripe_price_id,
      status: "active",
      quantity: 1,
      current_period_start: Time.current,
      current_period_end: 1.month.from_now
    )
  end
end
