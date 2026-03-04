require "rails_helper"
require "securerandom"

RSpec.describe "Licenses API", type: :request do
  let(:encoder) { Licenses::LicenseKeyEncoder.new(primary_key: ENV["EA_LICENSE_PRIMARY_KEY"], secondary_key: ENV["EA_LICENSE_SECRET_KEY"]) }
  let(:user) { create(:user, email: "api-user@example.com") }
  let(:expert_advisor) { create(:expert_advisor, ea_id: "ea-api") }
  let(:expires_at) { 5.days.from_now }
  let(:license_key) { encoder.generate(email: user.email, ea_id: expert_advisor.ea_id, expires_at: expires_at) }
  let(:source_id) { ENV.fetch("EA_LICENSE_SOURCE_ID", "trading_sniper_floor") }
  let(:broker_account_payload) do
    {
      name: "Account A",
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
      trial_ends_at: nil,
      expires_at: expires_at,
      encrypted_key: license_key
    )
  end

  it "returns ok for valid payload" do
    post "/api/v1/licenses/verify", params: verify_params

    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body["ok"]).to eq(true)
    expect(body["trial"]).to eq(false)
    expect(body["expires_at"]).to eq(expires_at.to_i)
    expect(body["magic_number"]).to be > 0
    expect(body["granted_addons"]).to eq([])
  end

  it "returns the same magic number for repeated verify on the same lane" do
    post "/api/v1/licenses/verify", params: verify_params
    first_magic = JSON.parse(response.body).fetch("magic_number")

    post "/api/v1/licenses/verify", params: verify_params
    second_magic = JSON.parse(response.body).fetch("magic_number")

    expect(first_magic).to eq(second_magic)
  end

  it "rejects invalid sources" do
    post "/api/v1/licenses/verify", params: verify_params(source: "bad_source")

    expect(response).to have_http_status(:unauthorized)
    body = JSON.parse(response.body)
    expect(body["ok"]).to eq(false)
    expect(body["error"]).to eq("invalid_source")
  end

  it "rejects verify payloads without broker identity" do
    post "/api/v1/licenses/verify", params: verify_params.except(:broker_account)

    expect(response).to have_http_status(:unprocessable_content)
    body = JSON.parse(response.body)
    expect(body["ok"]).to eq(false)
    expect(body["error"]).to eq("invalid_payload")
  end

  it "creates or reuses broker accounts from payload" do
    expect do
      post "/api/v1/licenses/verify", params: verify_params
    end.to change(BrokerAccount, :count).by(1)

    body = JSON.parse(response.body)
    expect(body["broker_account"]["company"]).to eq("BrokerX")
    expect(body["broker_account"]["account_number"]).to eq(9876)

    expect do
      post "/api/v1/licenses/verify", params: verify_params(broker_account: broker_account_payload.merge(name: "Updated Name"))
    end.not_to change(BrokerAccount, :count)

    expect(BrokerAccount.first.name).to eq("Account A")
  end

  it "rejects missing addon access" do
    addon = create(:addon, key: "news_filter", addonable: expert_advisor)

    post "/api/v1/licenses/verify", params: verify_params(addons: addon.key)

    expect(response).to have_http_status(:unauthorized)
    body = JSON.parse(response.body)
    expect(body["ok"]).to eq(false)
    expect(body["error"]).to eq("addons_required")
    expect(body["required_addons"]).to eq(addon.key)
    expect(body["missing_addons"]).to eq(addon.key)
  end

  it "allows access when required addons are purchased" do
    addon = create(:addon, key: "news_filter", addonable: expert_advisor)
    create(:marketplace_purchase, user: user, billing_plan: addon.billing_plan)

    post "/api/v1/licenses/verify", params: verify_params(addons: addon.key)

    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body["ok"]).to eq(true)
    expect(body["granted_addons"]).to eq([addon.key])
  end

  it "allows privileged users with role-based access and no addon purchases" do
    privileged_user = create(:user, :full_trader, email: "privileged-api@example.com")
    privileged_ea = create(:expert_advisor, ea_id: "ea-privileged-api")
    addon = create(:addon, key: "risk_guard", addonable: privileged_ea)
    privileged_key = Licenses::PrivilegedAccess.generated_key_for(
      user: privileged_user,
      expert_advisor: privileged_ea,
      encoder: encoder
    )

    post "/api/v1/licenses/verify", params: {
      source: source_id,
      email: privileged_user.email,
      ea_id: privileged_ea.ea_id,
      license_key: privileged_key,
      addons: addon.key,
      broker_account: broker_account_payload
    }

    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body["ok"]).to eq(true)
    expect(body["trial"]).to eq(false)
    expect(body["magic_number"]).to be > 0
    expect(body["granted_addons"]).to eq([addon.key])
    expect(privileged_user.licenses.find_by(expert_advisor: privileged_ea)&.source).to eq("role_access")
  end

  it "returns lifetime expiration after subscription sync when the license is one-time" do
    lifetime_key = encoder.generate(
      email: user.email,
      ea_id: expert_advisor.ea_id,
      expires_at: License::LIFETIME_EXPIRES_AT
    )
    license.update!(
      status: "active",
      access_source: "one_time",
      source: "stripe_charge",
      plan_interval: nil,
      trial_ends_at: nil,
      expires_at: nil,
      encrypted_key: lifetime_key
    )

    plan = create(
      :billing_plan,
      tier: "basic",
      key: "basic_monthly",
      interval: "month",
      interval_count: 1,
      stripe_price_id: "price_basic_lifetime"
    )
    customer = user.pay_customers.create!(
      processor: "stripe",
      processor_id: "cus_#{SecureRandom.hex(4)}",
      default: true
    )
    subscription = customer.subscriptions.create!(
      name: "default",
      processor_id: "sub_#{SecureRandom.hex(4)}",
      processor_plan: plan.stripe_price_id,
      status: "active",
      quantity: 1,
      current_period_start: Time.current,
      current_period_end: 1.month.from_now
    )

    sync_encoder = instance_double(Licenses::LicenseKeyEncoder, generate: "SYNCED")
    Licenses::SubscriptionLicenseSync.new(subscription_id: subscription.id, encoder: sync_encoder).call

    license.reload
    expect(license.access_source).to eq("one_time")
    expect(license.encrypted_key).to eq(lifetime_key)

    post "/api/v1/licenses/verify", params: verify_params(license_key: lifetime_key)

    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body["ok"]).to eq(true)
    expect(body["trial"]).to eq(false)
    expect(body["expires_at"]).to eq(License::LIFETIME_EXPIRES_AT.to_i)
    expect(body["magic_number"]).to be > 0
  end

  it "rejects new connections when subscription seat cap is exhausted" do
    plan = create(
      :billing_plan,
      tier: "basic",
      key: "basic_monthly",
      interval: "month",
      interval_count: 1,
      sort_order: 1,
      stripe_price_id: "price_basic_limit"
    )
    create_pay_subscription(user: user, plan: plan)

    5.times do |idx|
      create(
        :license_online_session,
        user: user,
        expert_advisor: (idx.even? ? expert_advisor : create(:expert_advisor, ea_id: "ea-#{idx}")),
        company: "sub#{idx}",
        account_number: 7000 + idx,
        account_type: "real",
        entitlement_source: "subscription",
        last_seen_at: Time.current
      )
    end

    post "/api/v1/licenses/verify", params: verify_params(
      broker_account: broker_account_payload.merge(company: "Overflow", account_number: 9090)
    )

    expect(response).to have_http_status(:too_many_requests)
    body = JSON.parse(response.body)
    expect(body["ok"]).to eq(false)
    expect(body["error"]).to eq("online_limit_reached")
    expect(body["subscription_cap"]).to eq(5)
  end

  def verify_params(overrides = {})
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
