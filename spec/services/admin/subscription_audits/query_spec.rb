require "rails_helper"

RSpec.describe Admin::SubscriptionAudits::Query do
  let(:pandora_ea) { create(:expert_advisor, ea_id: "pandora_box") }
  let(:chu_ea) { create(:expert_advisor, ea_id: "chu_sniper_trailing") }
  let(:monthly_plan) do
    create(
      :billing_plan,
      tier: "pandora_pro",
      key: "pandora_pro_monthly",
      interval: "month",
      interval_count: 1,
      amount_cents: 7900
    ).tap { |plan| create(:billing_plan_entitlement, billing_plan: plan, expert_advisor: pandora_ea) }
  end
  let(:annual_plan) do
    create(
      :billing_plan,
      :annual,
      tier: "pandora_pro",
      key: "pandora_pro_annual",
      amount_cents: 61_620
    ).tap { |plan| create(:billing_plan_entitlement, billing_plan: plan, expert_advisor: pandora_ea) }
  end

  it "returns only users with Stripe or manual subscription history and applies audit filters" do
    stripe_user = create(:user, email: "stripe-audit@example.com")
    manual_user = create(:user, email: "manual-audit@example.com")
    create(:user, email: "no-history@example.com")
    create_subscription(user: stripe_user, plan: monthly_plan, status: "active", period_end: 20.days.from_now)
    create(
      :manual_subscription,
      user: manual_user,
      billing_plan: annual_plan,
      status: "expired",
      starts_at: 2.months.ago,
      ends_at: 1.month.ago
    )

    expect(described_class.new.call).to contain_exactly(stripe_user, manual_user)
    expect(described_class.new(filters: { audit: { email: "stripe-audit" } }).call).to contain_exactly(stripe_user)
    expect(described_class.new(filters: { audit: { source: "manual" } }).call).to contain_exactly(manual_user)
    expect(described_class.new(filters: { audit: { status: "active" } }).call).to contain_exactly(stripe_user)
    expect(described_class.new(filters: { audit: { interval: "year" } }).call).to contain_exactly(manual_user)
    expect(
      described_class.new(filters: { audit: { period_end_from: 10.days.from_now.to_date.iso8601 } }).call
    ).to contain_exactly(stripe_user)
  end

  it "builds exact mixed-currency totals and normalized local audit evidence" do
    user = create(:user)
    admin = create(:user, :admin)
    promotion = create(:promotion_code, code: "AUDIT20", percent_off: 20)
    referrer = create(:user)
    partner_profile = create(:partner_profile, user: referrer, referral_code: "PARTNER10", discount_percent: 10)
    referral = Refer::Referral.create!(
      referrer: referrer,
      referee: user,
      referral_code: referrer.referral_codes.find_by!(code: partner_profile.referral_code)
    )
    subscription = create_subscription(
      user: user,
      plan: monthly_plan,
      status: "active",
      period_end: 1.month.from_now,
      metadata: {
        "dashboard_promotion_id" => promotion.id.to_s,
        "dashboard_promotion_code" => promotion.code,
        "dashboard_promotion_percent" => "20",
        "partner_referral_code" => "PARTNER10",
        "referral_discount_percent" => "10"
      }
    )
    customer = subscription.customer
    Pay::Charge.create!(
      customer: customer,
      subscription: subscription,
      processor_id: "ch_usd",
      amount: 10_000,
      amount_refunded: 2000,
      currency: "usd"
    )
    Pay::Charge.create!(customer: customer, processor_id: "ch_eur", amount: 5000, currency: "eur")
    Pay::Charge.create!(
      customer: customer,
      processor_id: "ch_failed",
      amount: 9900,
      currency: "usd",
      data: { "status" => "failed" }
    )
    create(
      :manual_subscription,
      user: user,
      billing_plan: monthly_plan,
      recorded_by_admin: admin,
      amount_cents: 7900,
      payment_status: "paid",
      status: "superseded",
      superseded_at: Time.current,
      superseded_by_pay_subscription: subscription
    )
    create(
      :manual_subscription,
      user: user,
      billing_plan: monthly_plan,
      recorded_by_admin: admin,
      amount_cents: 7900,
      payment_status: "pending",
      paid_at: nil,
      status: "superseded",
      superseded_at: Time.current,
      superseded_by_pay_subscription: subscription,
      starts_at: 2.months.from_now,
      ends_at: 3.months.from_now
    )
    create(
      :manual_subscription,
      user: user,
      billing_plan: monthly_plan,
      recorded_by_admin: admin,
      amount_cents: 0,
      payment_status: "complimentary",
      paid_at: nil,
      status: "superseded",
      superseded_at: Time.current,
      superseded_by_pay_subscription: subscription,
      starts_at: 4.months.from_now,
      ends_at: 5.months.from_now
    )
    Pay::Webhook.create!(
      processor: "stripe",
      event_type: "invoice.payment_failed",
      event: {
        "data" => {
          "object" => {
            "id" => "in_failed",
            "customer" => customer.processor_id,
            "subscription" => subscription.processor_id,
            "status" => "open",
            "amount_due" => 7900,
            "currency" => "usd"
          }
        }
      }
    )
    license = create(
      :license,
      user: user,
      expert_advisor: pandora_ea,
      status: "active",
      trial_ends_at: nil,
      expires_at: 1.month.from_now
    )
    chu_license = create(
      :license,
      user: user,
      expert_advisor: chu_ea,
      status: "active",
      trial_ends_at: nil,
      expires_at: 1.month.from_now
    )
    event = create(
      :admin_audit_event,
      actor: admin,
      target: user,
      action: AdminAuditEvent::ACTIONS.fetch(:subscription_licenses_rotated),
      metadata: { "affected_license_count" => 1, "affected_license_ids" => [ license.id ] }
    )

    presenter = described_class.new.presenters_for([ user ]).fetch(user.id)
    usd = presenter.payment_totals.find { |total| total[:currency] == "usd" }
    eur = presenter.payment_totals.find { |total| total[:currency] == "eur" }

    expect(usd).to include(
      stripe_gross_cents: 10_000,
      refunds_cents: 2000,
      manual_paid_cents: 7900,
      settled_net_cents: 15_900
    )
    expect(eur).to include(stripe_gross_cents: 5000, refunds_cents: 0, settled_net_cents: 5000)
    expect(presenter.payment_history.map(&:state)).to include("succeeded", "refunded", "failed")
    expect(presenter.payment_history.find { |entry| entry.processor_reference == "ch_failed" }.state).to eq("failed")
    expect(presenter.promotion_entries.first).to include(code: "AUDIT20", percent: 20)
    expect(presenter.referral_entries.first).to include(code: "PARTNER10", percent: 10)
    expect(presenter.referral_relationship).to include(
      code: "PARTNER10",
      referrer_id: referrer.id,
      discount_percent: 10,
      completed_at: referral.completed_at
    )
    expect(presenter.licenses).to contain_exactly(license, chu_license)
    expect(presenter.audit_events).to contain_exactly(event)
    expect(presenter.manual_grants.map(&:payment_status)).to include("paid", "pending", "complimentary")
  end

  it "labels missing plan and invoice snapshots as unavailable instead of inferring them" do
    user = create(:user)
    create_subscription(
      user: user,
      plan: monthly_plan,
      status: "active",
      period_end: nil,
      processor_plan: "price_missing"
    )

    presenter = described_class.new.presenters_for([ user ]).fetch(user.id)

    expect(presenter.plan_name).to be_nil
    expect(presenter.period_end).to be_nil
    expect(presenter.local_snapshot_warnings).to include(:plan_mapping, :period_end, :invoice_history)
  end

  def create_subscription(user:, plan:, status:, period_end:, metadata: {}, processor_plan: plan.stripe_price_id)
    customer = Pay::Customer.create!(
      owner: user,
      processor: "stripe",
      processor_id: "cus_#{SecureRandom.hex(5)}",
      default: true
    )
    Pay::Subscription.create!(
      customer: customer,
      name: "default",
      processor_id: "sub_#{SecureRandom.hex(5)}",
      processor_plan: processor_plan,
      status: status,
      quantity: 1,
      current_period_start: 1.day.ago,
      current_period_end: period_end,
      metadata: metadata
    )
  end
end
