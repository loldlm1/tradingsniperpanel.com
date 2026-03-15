require "rails_helper"
require "securerandom"

RSpec.describe Partners::CommissionBuilder do
  let(:referrer) { create(:user) }
  let!(:partner_profile) do
    create(
      :partner_profile,
      user: referrer,
      referral_code: "PARTNER10",
      discount_percent: 10,
      commission_percent: 10,
      payout_mode: :once_paid
    )
  end
  let(:referred_user) { create(:user) }
  let(:customer) do
    referred_user.pay_customers.create!(
      processor: "stripe",
      processor_id: "cus_#{SecureRandom.hex(4)}",
      default: true
    )
  end

  before do
    Referrals::AttachReferrer.new(user: referred_user, code: partner_profile.referral_code).call

    stripe_charge = instance_double(Stripe::Charge, balance_transaction: "txn_123")
    balance_tx = instance_double(Stripe::BalanceTransaction, net: 1_000, currency: "usd")
    allow(Stripe::Charge).to receive(:retrieve).and_return(stripe_charge)
    allow(Stripe::BalanceTransaction).to receive(:retrieve).and_return(balance_tx)
  end

  it "creates the first commission for a referred subscription charge" do
    subscription = customer.subscriptions.create!(
      name: "default",
      processor_id: "sub_#{SecureRandom.hex(4)}",
      processor_plan: "price_basic_monthly",
      status: "active",
      quantity: 1,
      current_period_start: Time.current,
      current_period_end: 1.month.from_now,
      type: "Pay::Stripe::Subscription"
    )
    charge = customer.charges.create!(
      processor_id: "ch_#{SecureRandom.hex(4)}",
      amount: 1_000,
      currency: "usd",
      subscription: subscription,
      type: "Pay::Stripe::Charge"
    )

    result = described_class.new(pay_charge_id: charge.id).call

    expect(result).to be_present
    expect(result.commission_kind).to eq("initial")
    expect(result.amount_cents).to eq(100)
  end

  it "does not create a renewal commission after the first referred subscription charge" do
    subscription = customer.subscriptions.create!(
      name: "default",
      processor_id: "sub_#{SecureRandom.hex(4)}",
      processor_plan: "price_basic_monthly",
      status: "active",
      quantity: 1,
      current_period_start: Time.current,
      current_period_end: 1.month.from_now,
      type: "Pay::Stripe::Subscription"
    )
    first_charge = customer.charges.create!(
      processor_id: "ch_#{SecureRandom.hex(4)}",
      amount: 1_000,
      currency: "usd",
      subscription: subscription,
      type: "Pay::Stripe::Charge"
    )
    described_class.new(pay_charge_id: first_charge.id).call
    Referrals::MarkCompleted.new(user: referred_user).call

    renewal_charge = customer.charges.create!(
      processor_id: "ch_#{SecureRandom.hex(4)}",
      amount: 1_000,
      currency: "usd",
      subscription: subscription,
      type: "Pay::Stripe::Charge"
    )

    expect(described_class.new(pay_charge_id: renewal_charge.id).call).to be_nil
    expect(PartnerCommission.where(partner_profile: partner_profile, referred_user: referred_user).count).to eq(1)
  end

  it "does not create a commission after a completed referral starts a new subscription later" do
    first_subscription = customer.subscriptions.create!(
      name: "default",
      processor_id: "sub_#{SecureRandom.hex(4)}",
      processor_plan: "price_basic_monthly",
      status: "active",
      quantity: 1,
      current_period_start: Time.current,
      current_period_end: 1.month.from_now,
      type: "Pay::Stripe::Subscription"
    )
    first_charge = customer.charges.create!(
      processor_id: "ch_#{SecureRandom.hex(4)}",
      amount: 1_000,
      currency: "usd",
      subscription: first_subscription,
      type: "Pay::Stripe::Charge"
    )
    described_class.new(pay_charge_id: first_charge.id).call
    Referrals::MarkCompleted.new(user: referred_user).call

    new_subscription = customer.subscriptions.create!(
      name: "default",
      processor_id: "sub_#{SecureRandom.hex(4)}",
      processor_plan: "price_basic_monthly",
      status: "active",
      quantity: 1,
      current_period_start: Time.current,
      current_period_end: 1.month.from_now,
      type: "Pay::Stripe::Subscription"
    )
    later_charge = customer.charges.create!(
      processor_id: "ch_#{SecureRandom.hex(4)}",
      amount: 1_000,
      currency: "usd",
      subscription: new_subscription,
      type: "Pay::Stripe::Charge"
    )

    expect(described_class.new(pay_charge_id: later_charge.id).call).to be_nil
    expect(PartnerCommission.where(partner_profile: partner_profile, referred_user: referred_user).count).to eq(1)
  end

  it "still creates the first commission when referral completion was recorded after the charge timestamp" do
    subscription = customer.subscriptions.create!(
      name: "default",
      processor_id: "sub_#{SecureRandom.hex(4)}",
      processor_plan: "price_basic_monthly",
      status: "active",
      quantity: 1,
      current_period_start: Time.current,
      current_period_end: 1.month.from_now,
      type: "Pay::Stripe::Subscription"
    )
    charge = customer.charges.create!(
      processor_id: "ch_#{SecureRandom.hex(4)}",
      amount: 1_000,
      currency: "usd",
      subscription: subscription,
      type: "Pay::Stripe::Charge"
    )
    charge.update_column(:created_at, 5.minutes.ago)
    referred_user.referral.update_column(:completed_at, 1.minute.ago)

    result = described_class.new(pay_charge_id: charge.id).call

    expect(result).to be_present
    expect(result.commission_kind).to eq("initial")
  end
end
