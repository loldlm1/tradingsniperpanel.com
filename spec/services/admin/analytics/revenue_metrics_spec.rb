require "rails_helper"

RSpec.describe Admin::Analytics::RevenueMetrics, type: :service do
  it "aggregates stripe, manual, and partner commission metrics" do
    starts_at = Time.utc(2026, 1, 1)
    ends_at = Time.utc(2026, 1, 31, 23, 59, 59)
    range = starts_at..ends_at

    stripe_user = create(:user)
    stripe_customer = Pay::Customer.create!(owner: stripe_user, processor: "stripe", processor_id: "cus_1", default: true)
    plan = create(:billing_plan, tier: "pro", interval: "month", interval_count: 1)
    Pay::Subscription.create!(
      customer: stripe_customer,
      name: "default",
      processor_id: "sub_1",
      processor_plan: plan.stripe_price_id,
      status: "active",
      current_period_end: ends_at + 1.day
    )
    Pay::Charge.create!(
      customer: stripe_customer,
      processor_id: "ch_1",
      amount: 1000,
      amount_refunded: 200,
      data: { "status" => "succeeded" },
      created_at: starts_at + 1.day,
      updated_at: starts_at + 1.day
    )

    manual_user = create(:user)
    create(:manual_transaction, user: manual_user, paid_at: starts_at + 2.days, amount_cents: 500)
    create(:manual_subscription, user: manual_user, paid_at: starts_at + 3.days, amount_cents: 1200, ends_at: ends_at + 2.days)

    partner = create(:user, :partner)
    partner_profile = partner.partner_profile || PartnerProfile.create!(user: partner)
    partner_membership = PartnerMembership.create!(partner_profile: partner_profile, user: manual_user, depth: 1)
    PartnerCommission.create!(
      partner_profile: partner_profile,
      partner_membership: partner_membership,
      referred_user: manual_user,
      commission_kind: :initial,
      status: :pending,
      amount_cents: 100,
      currency: "usd",
      occurred_at: starts_at + 4.days
    )

    create(:marketplace_purchase, user: manual_user, purchased_at: starts_at + 2.days)

    metrics = described_class.new(starts_at: starts_at, ends_at: ends_at).call

    expect(metrics.stripe_gross_cents).to eq(1000)
    expect(metrics.stripe_refunds_cents).to eq(200)
    expect(metrics.manual_gross_cents).to eq(1700)
    expect(metrics.gross_cents).to eq(2700)
    expect(metrics.partner_commissions_cents).to eq(100)
    expect(metrics.net_cents).to eq(2400)
    expect(metrics.marketplace_purchases_count).to eq(1)
    expect(metrics.unique_buyers_count).to eq(1)
    expect(metrics.subscribed_users_count).to eq(2)
  end
end
