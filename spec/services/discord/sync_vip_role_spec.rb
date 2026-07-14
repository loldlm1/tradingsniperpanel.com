require "rails_helper"

RSpec.describe Discord::SyncVipRole do
  let(:connection) { create(:discord_connection, :connected) }
  let(:client) do
    instance_double(
      Discord::Client,
      add_vip_role: true,
      remove_vip_role: true
    )
  end
  let(:logger) { instance_double(ActiveSupport::Logger, warn: nil) }

  before do
    allow(Discord).to receive(:enabled?).and_return(true)
  end

  it "grants the configured role for an eligible connection" do
    result = build_service(eligibility_values: [ true ]).call

    expect(result.outcome).to eq(:granted)
    expect(client).to have_received(:add_vip_role).with(user_id: connection.discord_user_id)
    expect(client).not_to have_received(:remove_vip_role)
    expect(connection.reload).to have_attributes(
      vip_role_state: "granted",
      sync_status: "idle",
      sync_started_at: nil,
      last_error_code: nil
    )
    expect(connection.last_synced_at).to be_present
  end

  it "removes the configured role for an ineligible connection" do
    result = build_service(eligibility_values: [ false ]).call

    expect(result.outcome).to eq(:removed)
    expect(client).to have_received(:remove_vip_role).with(user_id: connection.discord_user_id)
    expect(connection.reload.vip_role_state).to eq("removed")
  end

  it "forces removal while disconnect is pending" do
    connection.update!(disconnect_requested_at: Time.current)

    build_service(eligibility_values: [ true ]).call

    expect(client).to have_received(:remove_vip_role).with(user_id: connection.discord_user_id)
  end

  it "prevents a second operation while a live lease is held" do
    connection.update!(sync_status: "syncing", sync_started_at: 1.minute.ago)

    result = build_service(eligibility_values: [ true ]).call

    expect(result.outcome).to eq(:lease_held)
    expect(client).not_to have_received(:add_vip_role)
    expect(client).not_to have_received(:remove_vip_role)
  end

  it "reclaims a stale lease" do
    connection.update!(sync_status: "syncing", sync_started_at: 10.minutes.ago)

    result = build_service(eligibility_values: [ true ]).call

    expect(result.outcome).to eq(:granted)
    expect(client).to have_received(:add_vip_role).once
  end

  it "prevents conflicting provider operations during an in-flight call" do
    nested_client = instance_double(Discord::Client, add_vip_role: true, remove_vip_role: true)
    nested_result = nil
    allow(client).to receive(:add_vip_role) do
      nested_result = build_service(client: nested_client, eligibility_values: [ false ]).call
      true
    end

    result = build_service(eligibility_values: [ true ]).call

    expect(result.outcome).to eq(:granted)
    expect(nested_result.outcome).to eq(:lease_held)
    expect(nested_client).not_to have_received(:add_vip_role)
    expect(nested_client).not_to have_received(:remove_vip_role)
  end

  it "requests a follow-up when eligibility changes during the provider call" do
    result = build_service(eligibility_values: [ true, false ]).call

    expect(result).to be_follow_up
    expect(connection.reload.vip_role_state).to eq("granted")
  end

  it "returns Discord rate-limit delay and records a safe failure" do
    allow(client).to receive(:add_vip_role).and_raise(
      Discord::RateLimitedError.new(code: :rate_limited, status: 429, retry_after: 2.5)
    )

    result = build_service(eligibility_values: [ true ]).call

    expect(result).to be_rate_limited
    expect(result.retry_after).to eq(2.5)
    expect(connection.reload).to have_attributes(
      sync_status: "failed",
      sync_started_at: nil,
      last_error_code: "rate_limited"
    )
  end

  it "marks transient server failures as retryable" do
    allow(client).to receive(:add_vip_role).and_raise(
      Discord::ServerError.new(code: :server_error, status: 503)
    )

    result = build_service(eligibility_values: [ true ]).call

    expect(result).to be_retryable
    expect(connection.reload.last_error_code).to eq("server_error")
  end

  it "records authorization failures without requesting an immediate retry" do
    allow(client).to receive(:add_vip_role).and_raise(
      Discord::ForbiddenError.new(code: :forbidden, status: 403)
    )

    result = build_service(eligibility_values: [ true ]).call

    expect(result.outcome).to eq(:operational_failure)
    expect(result).not_to be_retryable
    expect(connection.reload.last_error_code).to eq("forbidden")
    expect(logger).to have_received(:warn).with(
      "Discord VIP sync failed connection_id=#{connection.id} code=forbidden"
    )
  end

  it "does nothing while the integration is disabled" do
    allow(Discord).to receive(:enabled?).and_return(false)

    result = build_service(eligibility_values: [ true ]).call

    expect(result.outcome).to eq(:disabled)
    expect(client).not_to have_received(:add_vip_role)
  end

  it "converges scheduled cancellation, renewal failure, and payment recovery from current Pay state" do
    plan = pandora_plan
    customer = connection.user.pay_customers.create!(
      processor: "stripe",
      processor_id: "cus_discord_sync",
      default: true
    )
    subscription = customer.subscriptions.create!(
      name: "default",
      processor_id: "sub_discord_sync",
      processor_plan: plan.stripe_price_id,
      status: "active",
      quantity: 1,
      current_period_start: Time.current,
      current_period_end: 1.month.from_now,
      ends_at: 1.month.from_now
    )

    described_class.new(connection_id: connection.id, client: client, logger: logger).call
    subscription.update!(status: "past_due")
    described_class.new(connection_id: connection.id, client: client, logger: logger).call
    subscription.update!(status: "active")
    described_class.new(connection_id: connection.id, client: client, logger: logger).call

    expect(client).to have_received(:add_vip_role).twice
    expect(client).to have_received(:remove_vip_role).once
    expect(connection.reload.vip_role_state).to eq("granted")
  end

  it "converges active and expired manual Pandora grants" do
    manual = create(
      :manual_subscription,
      user: connection.user,
      billing_plan: pandora_plan,
      starts_at: 1.day.ago,
      ends_at: 1.month.from_now
    )

    described_class.new(connection_id: connection.id, client: client, logger: logger).call
    manual.update!(ends_at: 1.second.ago)
    described_class.new(connection_id: connection.id, client: client, logger: logger).call

    expect(client).to have_received(:add_vip_role).once
    expect(client).to have_received(:remove_vip_role).once
    expect(connection.reload.vip_role_state).to eq("removed")
  end

  def build_service(client: self.client, eligibility_values:)
    values = eligibility_values.dup
    eligibility = instance_double(Discord::VipEligibility)
    allow(eligibility).to receive(:call) do
      eligible = values.length > 1 ? values.shift : values.first
      Discord::VipEligibility::Result.new(
        eligible: eligible,
        source: :stripe,
        plan_key: Billing::PandoraPricing::MONTHLY_KEY,
        reason: eligible ? "eligible_stripe" : "past_due"
      )
    end
    eligibility_class = class_double(Discord::VipEligibility, new: eligibility)

    described_class.new(
      connection_id: connection.id,
      client: client,
      eligibility_class: eligibility_class,
      logger: logger
    )
  end

  def pandora_plan
    BillingPlan.find_by(key: Billing::PandoraPricing::MONTHLY_KEY) || create(
      :billing_plan,
      tier: Billing::PandoraPricing::TIER,
      key: Billing::PandoraPricing::MONTHLY_KEY,
      name: "Pandora Discord Monthly",
      amount_cents: Billing::PandoraPricing::MONTHLY_CENTS,
      stripe_price_id: "price_pandora_discord_monthly"
    )
  end
end
