require "rails_helper"
require "securerandom"

RSpec.describe "Licenses API", type: :request do
  let(:encoder) { Licenses::LicenseKeyEncoder.new(primary_key: ENV["EA_LICENSE_PRIMARY_KEY"], secondary_key: ENV["EA_LICENSE_SECRET_KEY"]) }
  let(:user) { create(:user, email: "api-user@example.com") }
  let(:expert_advisor) { create(:expert_advisor, ea_id: "ea-api") }
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
      token_version: token_version,
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
    expect(body["magic_number"]).to be <= Licenses::MagicNumberPolicy::MAX_VALUE
    expect(body["granted_addons"]).to eq([])
  end

  it "uses the unchanged v1 response contract for Chu without required add-ons" do
    chu = create(:expert_advisor, ea_id: "chu_sniper_trailing", ea_type: :ea_tool, trial_enabled: false)
    chu_expires_at = 5.days.from_now
    chu_key = encoder.generate(
      email: user.email,
      ea_id: chu.ea_id,
      expires_at: chu_expires_at,
      token_version: token_version
    )
    create(
      :license,
      user: user,
      expert_advisor: chu,
      status: "active",
      token_version: token_version,
      trial_ends_at: nil,
      expires_at: chu_expires_at,
      encrypted_key: chu_key
    )

    post "/api/v1/licenses/verify", params: verify_params(
      ea_id: chu.ea_id,
      license_key: chu_key,
      broker_account: broker_account_payload.merge(company: "ChuBroker", account_number: 7654)
    )

    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body).to include(
      "ok" => true,
      "trial" => false,
      "expires_at" => chu_expires_at.to_i,
      "granted_addons" => []
    )
    expect(body["magic_number"]).to be_between(1, Licenses::MagicNumberPolicy::MAX_VALUE)
  end

  it "rejects the previous token after rotation and accepts the current token" do
    previous_key = license.encrypted_key
    Licenses::RotateTokens.new(
      scope: :user,
      user: user,
      actor: create(:user, :admin),
      request_id: SecureRandom.uuid,
      encoder: encoder
    ).call

    post "/api/v1/licenses/verify", params: verify_params(license_key: previous_key)

    expect(response).to have_http_status(:unauthorized)
    expect(JSON.parse(response.body)["error"]).to eq("invalid_key")

    post "/api/v1/licenses/verify", params: verify_params(license_key: license.reload.encrypted_key)

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)["ok"]).to eq(true)
  end

  it "treats blank addon payloads as base access" do
    post "/api/v1/licenses/verify", params: verify_params(addons: "")

    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body["ok"]).to eq(true)
    expect(body["granted_addons"]).to eq([])
  end

  it "returns the same magic number for repeated verify on the same lane" do
    post "/api/v1/licenses/verify", params: verify_params
    first_magic = JSON.parse(response.body).fetch("magic_number")

    post "/api/v1/licenses/verify", params: verify_params
    second_magic = JSON.parse(response.body).fetch("magic_number")

    expect(first_magic).to eq(second_magic)
  end

  it "remaps oversized legacy lane magic numbers on verify" do
    lane = create(
      :license_lane_magic_number,
      license: license,
      source: source_id,
      email: user.email,
      company: broker_account_payload.fetch(:company),
      account_number: broker_account_payload.fetch(:account_number),
      account_type: broker_account_payload.fetch(:account_type),
      magic_number: 123_456_789
    )
    previous_magic_number = 5_544_576_807_936_763_904
    lane.update_columns(magic_number: previous_magic_number)

    post "/api/v1/licenses/verify", params: verify_params

    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body["magic_number"]).to be <= Licenses::MagicNumberPolicy::MAX_VALUE

    lane = LicenseLaneMagicNumber.find_by!(
      license_id: license.id,
      source: source_id,
      email: user.email,
      company: broker_account_payload.fetch(:company).downcase,
      account_number: broker_account_payload.fetch(:account_number),
      account_type: broker_account_payload.fetch(:account_type)
    )
    expect(lane.magic_number).to eq(body.fetch("magic_number"))
    expect(lane.magic_number).not_to eq(previous_magic_number)
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
    expect(body["required_addon_keys"]).to eq([ addon.key ])
    expect(body["missing_addon_keys"]).to eq([ addon.key ])
  end

  it "returns only the missing addon keys when some requested addons are already owned" do
    owned_addon = create(:addon, key: "news_filter", addonable: expert_advisor)
    missing_addon = create(:addon, key: "volatility_trap", addonable: expert_advisor)
    create(:marketplace_purchase, user: user, billing_plan: owned_addon.billing_plan)

    post "/api/v1/licenses/verify", params: verify_params(addons: "#{owned_addon.key},#{missing_addon.key}")

    expect(response).to have_http_status(:unauthorized)
    body = JSON.parse(response.body)
    expect(body["ok"]).to eq(false)
    expect(body["error"]).to eq("addons_required")
    expect(body["required_addons"]).to eq("#{owned_addon.key},#{missing_addon.key}")
    expect(body["missing_addons"]).to eq(missing_addon.key)
    expect(body["required_addon_keys"]).to eq([ owned_addon.key, missing_addon.key ])
    expect(body["missing_addon_keys"]).to eq([ missing_addon.key ])
  end

  it "allows access when required addons are purchased" do
    addon = create(:addon, key: "news_filter", addonable: expert_advisor)
    create(:marketplace_purchase, user: user, billing_plan: addon.billing_plan)

    post "/api/v1/licenses/verify", params: verify_params(addons: addon.key)

    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body["ok"]).to eq(true)
    expect(body["granted_addons"]).to eq([ addon.key ])
  end

  it "returns license_not_found for every product role without entitlement" do
    role_ea = create(:expert_advisor, ea_id: "ea-role-only-api")

    %i[admin master_admin full_trader].each do |role|
      role_user = create(:user, role: role)

      expect do
        post "/api/v1/licenses/verify", params: {
          source: source_id,
          email: role_user.email,
          ea_id: role_ea.ea_id,
          license_key: "ROLE_ONLY_KEY",
          broker_account: broker_account_payload
        }
      end.not_to change(License, :count)

      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)["error"]).to eq("license_not_found")
    end
  end

  it "accepts a subscription-backed admin license" do
    admin = create(:user, :admin, email: "subscribed-admin@example.com")
    admin_ea = create(:expert_advisor, ea_id: "ea-subscribed-admin")
    admin_expires_at = 1.month.from_now
    admin_key = encoder.generate(
      email: admin.email,
      ea_id: admin_ea.ea_id,
      expires_at: admin_expires_at,
      token_version: 1
    )
    create(
      :license,
      user: admin,
      expert_advisor: admin_ea,
      status: "active",
      access_source: "subscription",
      source: "stripe_subscription",
      trial_ends_at: nil,
      expires_at: admin_expires_at,
      encrypted_key: admin_key
    )

    post "/api/v1/licenses/verify", params: {
      source: source_id,
      email: admin.email,
      ea_id: admin_ea.ea_id,
      license_key: admin_key,
      broker_account: broker_account_payload
    }

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)["ok"]).to eq(true)
  end

  it "returns lifetime expiration after subscription sync when the license is one-time" do
    lifetime_key = encoder.generate(
      email: user.email,
      ea_id: expert_advisor.ea_id,
      expires_at: License::LIFETIME_EXPIRES_AT,
      token_version: token_version
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
    expect(body["magic_number"]).to be <= Licenses::MagicNumberPolicy::MAX_VALUE
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
