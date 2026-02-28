require "rails_helper"
require "securerandom"

RSpec.describe Licenses::OnlineSeatAllocator do
  include ActiveSupport::Testing::TimeHelpers

  let(:user) { create(:user) }
  let(:ea1) { create(:expert_advisor, ea_id: "ea-one") }
  let(:ea2) { create(:expert_advisor, ea_id: "ea-two") }
  let!(:basic_plan) do
    create(
      :billing_plan,
      tier: "basic",
      key: "basic_monthly",
      interval: "month",
      interval_count: 1,
      sort_order: 1,
      stripe_price_id: "price_basic_monthly"
    )
  end

  before do
    create_pay_subscription(user: user, plan: basic_plan)
  end

  it "allocates one-time seats before subscription seats" do
    one_time_license = create(:license, :one_time, user: user, expert_advisor: ea1)

    result = allocate(license: one_time_license, broker_account: broker_identity(company: "BrokerX", account_number: 1001))

    expect(result).to be_ok
    expect(result.entitlement_source).to eq("one_time")
    expect(result.session).to be_present
  end

  it "dedupes repeated chart sessions for the same EA and broker identity" do
    license = create(:license, :one_time, user: user, expert_advisor: ea1)

    first = allocate(license: license, broker_account: broker_identity(company: "BrokerX", account_number: 2002))

    expect(first).to be_ok
    expect do
      second = allocate(license: license, broker_account: broker_identity(company: "brokerx", account_number: 2002))
      expect(second).to be_ok
      expect(second.session.id).to eq(first.session.id)
    end.not_to change(LicenseOnlineSession, :count)
  end

  it "falls back to subscription seats after one-time cap is exhausted" do
    license = create(:license, :one_time, user: user, expert_advisor: ea1)

    8.times do |idx|
      create(
        :license_online_session,
        user: user,
        expert_advisor: ea1,
        company: "broker#{idx}",
        account_number: 3000 + idx,
        account_type: "real",
        entitlement_source: "one_time",
        last_seen_at: Time.current
      )
    end

    result = allocate(license: license, broker_account: broker_identity(company: "BrokerY", account_number: 3999))

    expect(result).to be_ok
    expect(result.entitlement_source).to eq("subscription")
  end

  it "rejects connection when one-time and subscription capacity are both exhausted" do
    license = create(:license, :one_time, user: user, expert_advisor: ea1)

    8.times do |idx|
      create(
        :license_online_session,
        user: user,
        expert_advisor: ea1,
        company: "ot#{idx}",
        account_number: 4000 + idx,
        account_type: "real",
        entitlement_source: "one_time",
        last_seen_at: Time.current
      )
    end

    5.times do |idx|
      create(
        :license_online_session,
        user: user,
        expert_advisor: (idx.even? ? ea1 : ea2),
        company: "sub#{idx}",
        account_number: 5000 + idx,
        account_type: "real",
        entitlement_source: "subscription",
        last_seen_at: Time.current
      )
    end

    result = allocate(license: license, broker_account: broker_identity(company: "BrokerZ", account_number: 8888))

    expect(result).not_to be_ok
    expect(result.error).to eq(:online_limit_reached)
    expect(result.code).to eq(:too_many_requests)
    expect(result.details[:subscription_cap]).to eq(5)
    expect(result.details[:one_time_cap]).to eq(8)
  end

  it "ignores stale sessions older than ttl for seat counting" do
    license = create(:license, :one_time, user: user, expert_advisor: ea1)

    8.times do |idx|
      create(
        :license_online_session,
        user: user,
        expert_advisor: ea1,
        company: "stale#{idx}",
        account_number: 6000 + idx,
        account_type: "real",
        entitlement_source: "one_time",
        last_seen_at: 20.minutes.ago
      )
    end

    result = allocate(license: license, broker_account: broker_identity(company: "Fresh", account_number: 6999))

    expect(result).to be_ok
    expect(result.entitlement_source).to eq("one_time")
  end

  def allocate(license:, broker_account:)
    described_class.new(
      license: license,
      broker_account: broker_account,
      now: Time.current,
      ttl_seconds: 15.minutes.to_i
    ).call
  end

  def broker_identity(company:, account_number:, account_type: "real")
    {
      company: company,
      account_number: account_number,
      account_type: account_type
    }
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
