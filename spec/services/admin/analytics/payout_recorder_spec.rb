require "rails_helper"

RSpec.describe Admin::Analytics::PayoutRecorder do
  around do |example|
    Time.use_zone("UTC") { example.run }
  end

  it "creates a paid payout snapshot for the period" do
    master_admin = create(:user, :master_admin)
    create(:revenue_split_rule, effective_at: Time.zone.parse("2026-01-01"), us_percent: 40, client_percent: 60)
    create(
      :manual_transaction,
      amount_cents: 10_000,
      paid_at: Time.zone.parse("2026-01-10"),
      recorded_by_admin: master_admin
    )

    result = described_class.new(
      period_key: "first_half",
      as_of: Time.zone.parse("2026-01-10"),
      actor: master_admin
    ).call

    expect(result).to be_ok
    payout = result.payout
    expect(payout).to be_paid
    expect(payout.net_cents).to eq(10_000)
    expect(payout.us_cents).to eq(4_000)
    expect(payout.client_cents).to eq(6_000)
    expect(payout.starts_at).to eq(Time.zone.parse("2026-01-01").beginning_of_day)
    expect(payout.ends_at.to_i).to eq(Time.zone.parse("2026-01-15").end_of_day.to_i)
  end

  it "allows admins to create payouts" do
    admin = create(:user, :admin)
    create(:revenue_split_rule, effective_at: Time.zone.parse("2026-01-01"), us_percent: 40, client_percent: 60)
    create(
      :manual_transaction,
      amount_cents: 10_000,
      paid_at: Time.zone.parse("2026-01-10"),
      recorded_by_admin: admin
    )

    result = described_class.new(
      period_key: "first_half",
      as_of: Time.zone.parse("2026-01-10"),
      actor: admin
    ).call

    expect(result).to be_ok
    expect(RevenueSplitPayout.count).to eq(1)
  end

  it "rejects non-admin actors" do
    trader = create(:user)

    result = described_class.new(
      period_key: "first_half",
      as_of: Time.zone.parse("2026-01-10"),
      actor: trader
    ).call

    expect(result.ok?).to be(false)
    expect(RevenueSplitPayout.count).to eq(0)
  end
end
