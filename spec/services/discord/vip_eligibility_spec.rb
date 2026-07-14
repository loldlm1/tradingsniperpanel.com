require "rails_helper"

RSpec.describe Discord::VipEligibility do
  StripeSubscription = Struct.new(
    :processor_plan,
    :status,
    :current_period_end,
    :ends_at,
    :trial_ends_at,
    keyword_init: true
  ) do
    def past_due?
      status == "past_due"
    end

    def unpaid?
      status == "unpaid"
    end
  end

  let!(:pandora_monthly) do
    create(
      :billing_plan,
      tier: Billing::PandoraPricing::TIER,
      key: Billing::PandoraPricing::MONTHLY_KEY,
      name: "Pandora Monthly",
      amount_cents: Billing::PandoraPricing::MONTHLY_CENTS,
      stripe_price_id: "price_pandora_monthly"
    )
  end
  let(:user) { create(:user) }

  it "grants VIP for an active paid Stripe Pandora subscription" do
    result = eligibility_for(stripe_subscription(status: "active", current_period_end: 1.month.from_now), :stripe)

    expect(result).to be_eligible
    expect(result).to have_attributes(
      source: :stripe,
      plan_key: Billing::PandoraPricing::MONTHLY_KEY,
      reason: "eligible_stripe"
    )
  end

  it "keeps VIP for a scheduled cancellation until the paid period ends" do
    before_end = eligibility_for(
      stripe_subscription(status: "canceled", current_period_end: 1.day.from_now),
      :stripe
    )
    after_end = eligibility_for(
      stripe_subscription(status: "canceled", current_period_end: 1.second.ago),
      :stripe
    )

    expect(before_end).to be_eligible
    expect(after_end).not_to be_eligible
    expect(after_end.reason).to eq("inactive")
  end

  it "excludes trials" do
    result = eligibility_for(
      stripe_subscription(status: "trialing", current_period_end: 1.month.from_now, trial_ends_at: 1.week.from_now),
      :stripe
    )

    expect(result).not_to be_eligible
    expect(result.reason).to eq("trialing")
  end

  %w[past_due unpaid incomplete_expired].each do |status|
    it "excludes Stripe status #{status}" do
      result = eligibility_for(stripe_subscription(status: status, current_period_end: 1.month.from_now), :stripe)

      expect(result).not_to be_eligible
      expect(result.reason).to eq(status)
    end
  end

  it "restores eligibility after payment recovery" do
    failed = eligibility_for(stripe_subscription(status: "past_due", current_period_end: 1.month.from_now), :stripe)
    recovered = eligibility_for(stripe_subscription(status: "active", current_period_end: 1.month.from_now), :stripe)

    expect(failed).not_to be_eligible
    expect(recovered).to be_eligible
  end

  it "grants VIP for active paid and complimentary manual Pandora grants" do
    paid = create(:manual_subscription, user: user, billing_plan: pandora_monthly)
    complimentary = build(
      :manual_subscription,
      user: user,
      billing_plan: pandora_monthly,
      payment_status: "complimentary",
      amount_cents: 0,
      paid_at: nil
    )

    expect(eligibility_for(paid, :manual)).to be_eligible
    expect(eligibility_for(complimentary, :manual)).to be_eligible
  end

  it "excludes superseded and inactive manual grants" do
    superseded = instance_double(
      ManualSubscription,
      billing_plan: pandora_monthly,
      superseded?: true,
      active_for_time?: false
    )
    inactive = instance_double(
      ManualSubscription,
      billing_plan: pandora_monthly,
      superseded?: false,
      active_for_time?: false
    )

    expect(eligibility_for(superseded, :manual).reason).to eq("manual_superseded")
    expect(eligibility_for(inactive, :manual).reason).to eq("manual_inactive")
  end

  it "excludes the wrong tier" do
    other_plan = create(:billing_plan, tier: "other", key: "other_monthly", stripe_price_id: "price_other")
    subscription = stripe_subscription(
      processor_plan: other_plan.stripe_price_id,
      status: "active",
      current_period_end: 1.month.from_now
    )

    result = eligibility_for(subscription, :stripe)

    expect(result).not_to be_eligible
    expect(result.reason).to eq("wrong_tier")
  end

  it "excludes users without a current subscription" do
    result = described_class.new(
      user: user,
      finder: -> { Billing::ActiveSubscriptionFinder::Result.new }
    ).call

    expect(result).not_to be_eligible
    expect(result.reason).to eq("no_subscription")
  end

  def eligibility_for(subscription, source)
    access = Billing::ActiveSubscriptionFinder::Result.new(subscription: subscription, source: source)
    described_class.new(user: user, finder: -> { access }).call
  end

  def stripe_subscription(
    processor_plan: pandora_monthly.stripe_price_id,
    status:,
    current_period_end:,
    trial_ends_at: nil
  )
    StripeSubscription.new(
      processor_plan: processor_plan,
      status: status,
      current_period_end: current_period_end,
      ends_at: current_period_end,
      trial_ends_at: trial_ends_at
    )
  end
end
