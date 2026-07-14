require "rails_helper"
require "securerandom"

RSpec.describe "Subscription upgrades", type: :request do
  let(:user) { create(:user) }
  let(:customer) do
    user.pay_customers.create!(
      processor: "stripe",
      processor_id: "cus_#{SecureRandom.hex(4)}",
      default: true
    )
  end
  let!(:monthly_plan) do
    create(
      :billing_plan,
      tier: Billing::PandoraPricing::TIER,
      key: Billing::PandoraPricing::MONTHLY_KEY,
      interval: "month",
      interval_count: 1,
      stripe_price_id: "price_pandora_monthly",
      amount_cents: Billing::PandoraPricing::MONTHLY_CENTS
    )
  end
  let!(:annual_plan) do
    create(
      :billing_plan,
      :annual,
      tier: Billing::PandoraPricing::TIER,
      key: Billing::PandoraPricing::ANNUAL_KEY,
      stripe_price_id: "price_pandora_annual",
      amount_cents: Billing::PandoraPricing::ANNUAL_CENTS
    )
  end

  around do |example|
    original_env = ENV.to_hash
    ENV["STRIPE_PRIVATE_KEY"] = "sk_test_123"
    example.run
  ensure
    ENV.replace(original_env)
  end

  before do
    allow(Stripe::Subscription).to receive(:retrieve).and_return(double(schedule: nil))
    allow(Stripe::SubscriptionSchedule).to receive(:retrieve).and_return(double(status: "active"))
  end

  it "blocks checkout when a manual subscription exists for the same plan" do
    create(:manual_subscription, user: user, billing_plan: monthly_plan, starts_at: 1.day.ago, ends_at: 1.day.from_now)
    sign_in user, scope: :user

    post dashboard_checkout_path, params: { price_key: Billing::PandoraPricing::MONTHLY_KEY }

    expect(response).to redirect_to(dashboard_plans_path)
    expect(flash[:alert]).to eq(I18n.t("dashboard.plans.manual_unavailable"))
  end

  it "changes only new checkout success to localized Discord activation when enabled" do
    allow(Discord).to receive(:enabled?).and_return(true)
    checkout_stub = instance_double(Pay::Stripe::Customer)
    allow_any_instance_of(User).to receive(:payment_processor).and_return(checkout_stub)
    sign_in user, scope: :user

    expect(checkout_stub).to receive(:checkout) do |**params|
      expect(params).to include(
        mode: "subscription",
        line_items: [ { price: monthly_plan.stripe_price_id, quantity: 1 } ],
        success_url: dashboard_discord_connection_url(locale: :es, checkout: "success"),
        cancel_url: dashboard_plans_url(locale: :es),
        client_reference_id: user.id
      )
      expect(params.dig(:subscription_data, :metadata, :billing_plan_key)).to eq(monthly_plan.key)
      double(url: "https://checkout.test/discord-success")
    end

    post dashboard_checkout_path(locale: :es), params: { price_key: monthly_plan.key }

    expect(response).to redirect_to("https://checkout.test/discord-success")
  end

  it "keeps the existing dashboard success destination when Discord is disabled" do
    allow(Discord).to receive(:enabled?).and_return(false)
    checkout_stub = instance_double(Pay::Stripe::Customer)
    allow_any_instance_of(User).to receive(:payment_processor).and_return(checkout_stub)
    sign_in user, scope: :user

    expect(checkout_stub).to receive(:checkout) do |**params|
      expect(params[:success_url]).to eq(dashboard_url(price_key: monthly_plan.key))
      double(url: "https://checkout.test/dashboard-success")
    end

    post dashboard_checkout_path, params: { price_key: monthly_plan.key }

    expect(response).to redirect_to("https://checkout.test/dashboard-success")
  end

  it "allows every product role to start subscription checkout" do
    checkout_stub = instance_double(Pay::Stripe::Customer)
    allow_any_instance_of(User).to receive(:payment_processor).and_return(checkout_stub)
    expect(checkout_stub).to receive(:checkout).exactly(3).times do |**params|
      expect(params[:mode]).to eq("subscription")
      expect(params[:line_items]).to eq([ { price: monthly_plan.stripe_price_id, quantity: 1 } ])
      double(url: "https://checkout.test/role-subscription")
    end

    %i[admin master_admin full_trader].each do |role|
      role_user = create(:user, role: role)
      sign_in role_user, scope: :user

      post dashboard_checkout_path, params: { price_key: Billing::PandoraPricing::MONTHLY_KEY }

      expect(response).to redirect_to("https://checkout.test/role-subscription")
      sign_out role_user
    end
  end

  it "rejects active non-Pandora and one-time plan keys" do
    old_plan = create(:billing_plan, tier: "basic", key: "basic_monthly")
    one_time_plan = create(:billing_plan, :one_time)
    checkout_stub = instance_double(Pay::Stripe::Customer)
    allow_any_instance_of(User).to receive(:payment_processor).and_return(checkout_stub)
    expect(checkout_stub).not_to receive(:checkout)
    sign_in user, scope: :user

    [ old_plan.key, one_time_plan.key ].each do |price_key|
      post dashboard_checkout_path, params: { price_key: price_key }

      expect(response).to redirect_to(dashboard_plans_path)
      expect(flash[:alert]).to eq(I18n.t("dashboard.billing.invalid_price"))
    end
  end

  it "rejects inactive, stale-priced, and retired Pandora checkout values" do
    retired_price = create(:billing_plan_price, billing_plan: monthly_plan, active: false, retired_at: Time.current)
    checkout_stub = instance_double(Pay::Stripe::Customer)
    allow_any_instance_of(User).to receive(:payment_processor).and_return(checkout_stub)
    expect(checkout_stub).not_to receive(:checkout)
    sign_in user, scope: :user

    monthly_plan.update!(active: false)
    post dashboard_checkout_path, params: { price_key: Billing::PandoraPricing::MONTHLY_KEY }
    expect(response).to redirect_to(dashboard_plans_path)

    monthly_plan.update!(active: true, amount_cents: 9_999)
    post dashboard_checkout_path, params: { price_key: Billing::PandoraPricing::MONTHLY_KEY }
    expect(response).to redirect_to(dashboard_plans_path)

    post dashboard_checkout_path, params: { price_key: retired_price.stripe_price_id }
    expect(response).to redirect_to(dashboard_plans_path)
  end

  it "pre-applies the selected dashboard promotion code to checkout" do
    promotion = create(:promotion_code, :active, stripe_promotion_code_id: "promo_dashboard")
    checkout_stub = instance_double(Pay::Stripe::Customer)
    allow_any_instance_of(User).to receive(:payment_processor).and_return(checkout_stub)
    sign_in user, scope: :user

    expect(checkout_stub).to receive(:checkout) do |**params|
      expect(params[:discounts]).to eq([ { promotion_code: "promo_dashboard" } ])
      expect(params).not_to have_key(:allow_promotion_codes)
      double(url: "https://checkout.test/subscription")
    end

    post dashboard_checkout_path, params: { price_key: Billing::PandoraPricing::MONTHLY_KEY, promotion_code_id: promotion.id }

    expect(response).to redirect_to("https://checkout.test/subscription")
  end

  it "keeps the referral discount as the winning checkout discount" do
    promotion = create(:promotion_code, :active, stripe_promotion_code_id: "promo_dashboard")
    referrer = create(:user)
    referred_user = create(:user)
    create(:partner_profile, user: referrer, referral_code: "PARTNER20", discount_percent: 10)
    Referrals::AttachReferrer.new(user: referred_user, code: "PARTNER20").call
    referred_user.reload

    checkout_stub = instance_double(Pay::Stripe::Customer)
    allow_any_instance_of(User).to receive(:payment_processor).and_return(checkout_stub)
    allow(Partners::ReferralCoupon).to receive(:new).and_return(instance_double(Partners::ReferralCoupon, coupon_id: "coupon_referral"))
    sign_in referred_user, scope: :user

    expect(checkout_stub).to receive(:checkout) do |**params|
      expect(params[:discounts]).to eq([ { coupon: "coupon_referral" } ])
      expect(params[:discounts]).not_to eq([ { promotion_code: "promo_dashboard" } ])
      double(url: "https://checkout.test/referral")
    end

    post dashboard_checkout_path, params: { price_key: Billing::PandoraPricing::MONTHLY_KEY, promotion_code_id: promotion.id }

    expect(response).to redirect_to("https://checkout.test/referral")
  end

  it "falls back to dashboard promotions once a referral has been completed" do
    promotion = create(:promotion_code, :active, stripe_promotion_code_id: "promo_dashboard")
    referrer = create(:user)
    referred_user = create(:user)
    create(:partner_profile, user: referrer, referral_code: "PARTNER20", discount_percent: 10)
    Referrals::AttachReferrer.new(user: referred_user, code: "PARTNER20").call
    Referrals::MarkCompleted.new(user: referred_user).call

    checkout_stub = instance_double(Pay::Stripe::Customer)
    allow_any_instance_of(User).to receive(:payment_processor).and_return(checkout_stub)
    sign_in referred_user, scope: :user

    expect(checkout_stub).to receive(:checkout) do |**params|
      expect(params[:discounts]).to eq([ { promotion_code: "promo_dashboard" } ])
      expect(params[:discounts]).not_to eq([ { coupon: "coupon_referral" } ])
      double(url: "https://checkout.test/promotion")
    end

    post dashboard_checkout_path, params: { price_key: Billing::PandoraPricing::MONTHLY_KEY, promotion_code_id: promotion.id }

    expect(response).to redirect_to("https://checkout.test/promotion")
  end

  it "swaps an existing subscription instead of creating a new one" do
    existing = customer.subscriptions.create!(
      name: "default",
      processor_id: "sub_#{SecureRandom.hex(4)}",
      processor_plan: monthly_plan.stripe_price_id,
      status: "active",
      quantity: 1,
      current_period_start: Time.current,
      current_period_end: 1.month.from_now,
      type: "Pay::Stripe::Subscription"
    )

    expect_any_instance_of(Pay::Stripe::Subscription).to receive(:swap).with(annual_plan.stripe_price_id, hash_including(proration_behavior: "always_invoice")).and_return(true)

    sign_in user, scope: :user

    post dashboard_checkout_path, params: { price_key: Billing::PandoraPricing::ANNUAL_KEY }

    expect(response).to redirect_to(dashboard_plans_path)
    expect(flash[:notice]).to eq(I18n.t("dashboard.billing.upgraded"))
  end

  it "schedules a downgrade at period end for lower-priced plans" do
    subscription = customer.subscriptions.create!(
      name: "default",
      processor_id: "sub_#{SecureRandom.hex(4)}",
      processor_plan: annual_plan.stripe_price_id,
      status: "active",
      quantity: 1,
      current_period_start: Time.current,
      current_period_end: 1.month.from_now,
      type: "Pay::Stripe::Subscription"
    )

    schedule = instance_double(Stripe::SubscriptionSchedule, id: "sub_sched_123")
    allow(Stripe::Subscription).to receive(:retrieve).and_return(double(schedule: nil))
    expect(Stripe::SubscriptionSchedule).to receive(:create)
      .with(hash_including(from_subscription: subscription.processor_id), hash_including(idempotency_key: kind_of(String)))
      .and_return(schedule)
    expect(Stripe::SubscriptionSchedule).to receive(:update)
      .with("sub_sched_123", hash_including(end_behavior: "release", phases: kind_of(Array)))
      .and_return(schedule)
    expect_any_instance_of(Pay::Stripe::Subscription).not_to receive(:swap)

    sign_in user, scope: :user

    post dashboard_checkout_path, params: { price_key: Billing::PandoraPricing::MONTHLY_KEY }

    expect(response).to redirect_to(dashboard_plans_path)

    subscription.reload
    expect(subscription.metadata["scheduled_plan_key"]).to eq(Billing::PandoraPricing::MONTHLY_KEY)
    expect(subscription.metadata["scheduled_schedule_id"]).to eq("sub_sched_123")
    expect(subscription.metadata["scheduled_change_at"]).to be_present
  end

  it "updates an existing Stripe schedule when metadata is missing" do
    subscription = customer.subscriptions.create!(
      name: "default",
      processor_id: "sub_#{SecureRandom.hex(4)}",
      processor_plan: annual_plan.stripe_price_id,
      status: "active",
      quantity: 1,
      current_period_start: Time.current,
      current_period_end: 1.month.from_now,
      type: "Pay::Stripe::Subscription"
    )

    schedule = instance_double(Stripe::SubscriptionSchedule, id: "sub_sched_existing")
    allow(Stripe::Subscription).to receive(:retrieve).and_return(double(schedule: "sub_sched_existing"))
    expect(Stripe::SubscriptionSchedule).not_to receive(:create)
    expect(Stripe::SubscriptionSchedule).to receive(:update)
      .with("sub_sched_existing", hash_including(end_behavior: "release", phases: kind_of(Array)))
      .and_return(schedule)

    sign_in user, scope: :user

    post dashboard_checkout_path, params: { price_key: Billing::PandoraPricing::MONTHLY_KEY }

    expect(response).to redirect_to(dashboard_plans_path)

    subscription.reload
    expect(subscription.metadata["scheduled_schedule_id"]).to eq("sub_sched_existing")
  end

  it "creates a new schedule when the existing one is released" do
    subscription = customer.subscriptions.create!(
      name: "default",
      processor_id: "sub_#{SecureRandom.hex(4)}",
      processor_plan: annual_plan.stripe_price_id,
      status: "active",
      quantity: 1,
      current_period_start: Time.current,
      current_period_end: 1.month.from_now,
      metadata: { "scheduled_schedule_id" => "sub_sched_released" },
      type: "Pay::Stripe::Subscription"
    )

    allow(Stripe::SubscriptionSchedule).to receive(:retrieve)
      .with("sub_sched_released")
      .and_return(double(status: "released"))

    schedule = instance_double(Stripe::SubscriptionSchedule, id: "sub_sched_new")
    expect(Stripe::SubscriptionSchedule).to receive(:create)
      .with(hash_including(from_subscription: subscription.processor_id), hash_including(idempotency_key: kind_of(String)))
      .and_return(schedule)
    expect(Stripe::SubscriptionSchedule).to receive(:update)
      .with("sub_sched_new", hash_including(end_behavior: "release"))
      .and_return(schedule)

    sign_in user, scope: :user

    post dashboard_checkout_path, params: { price_key: Billing::PandoraPricing::MONTHLY_KEY }

    expect(response).to redirect_to(dashboard_plans_path)

    subscription.reload
    expect(subscription.metadata["scheduled_schedule_id"]).to eq("sub_sched_new")
  end

  it "backfills scheduled change details from Stripe when metadata is missing" do
    subscription = customer.subscriptions.create!(
      name: "default",
      processor_id: "sub_#{SecureRandom.hex(4)}",
      processor_plan: annual_plan.stripe_price_id,
      status: "active",
      quantity: 1,
      current_period_start: Time.current,
      current_period_end: 1.month.from_now,
      type: "Pay::Stripe::Subscription"
    )

    phase = double(start_date: 1.month.from_now.to_i, items: [ double(price: monthly_plan.stripe_price_id) ])
    schedule = double(id: "sub_sched_backfill", phases: [ phase ])
    allow(Stripe::Subscription).to receive(:retrieve).and_return(double(schedule: "sub_sched_backfill"))
    allow(Stripe::SubscriptionSchedule).to receive(:retrieve).and_return(schedule)

    sign_in user, scope: :user

    get dashboard_plans_path

    expect(response).to be_successful
    expect(response.body).to include(I18n.t("dashboard.plans.scheduled_badge"))

    subscription.reload
    expect(subscription.metadata["scheduled_plan_key"]).to eq(Billing::PandoraPricing::MONTHLY_KEY)
  end

  it "releases a scheduled downgrade when upgrading" do
    subscription = customer.subscriptions.create!(
      name: "default",
      processor_id: "sub_#{SecureRandom.hex(4)}",
      processor_plan: monthly_plan.stripe_price_id,
      status: "active",
      quantity: 1,
      current_period_start: Time.current,
      current_period_end: 1.month.from_now,
      metadata: {
        "scheduled_plan_key" => Billing::PandoraPricing::MONTHLY_KEY,
        "scheduled_schedule_id" => "sub_sched_789",
        "scheduled_change_at" => 1.month.from_now.iso8601
      },
      type: "Pay::Stripe::Subscription"
    )

    allow(Stripe::SubscriptionSchedule).to receive(:release).and_return(true)
    expect(Stripe::SubscriptionSchedule).to receive(:release).with("sub_sched_789")
    expect_any_instance_of(Pay::Stripe::Subscription).to receive(:swap).with(annual_plan.stripe_price_id, hash_including(proration_behavior: "always_invoice")).and_return(true)

    sign_in user, scope: :user

    post dashboard_checkout_path, params: { price_key: Billing::PandoraPricing::ANNUAL_KEY }

    expect(response).to redirect_to(dashboard_plans_path)

    subscription.reload
    expect(subscription.metadata).not_to include("scheduled_plan_key")
  end

  it "cancels a scheduled downgrade from the plans page" do
    subscription = customer.subscriptions.create!(
      name: "default",
      processor_id: "sub_#{SecureRandom.hex(4)}",
      processor_plan: annual_plan.stripe_price_id,
      status: "active",
      quantity: 1,
      current_period_start: Time.current,
      current_period_end: 1.month.from_now,
      metadata: {
        "scheduled_plan_key" => Billing::PandoraPricing::MONTHLY_KEY,
        "scheduled_schedule_id" => "sub_sched_789",
        "scheduled_change_at" => 1.month.from_now.iso8601
      },
      type: "Pay::Stripe::Subscription"
    )

    allow(Stripe::SubscriptionSchedule).to receive(:retrieve)
      .with("sub_sched_789")
      .and_return(double(status: "active"))
    expect(Stripe::SubscriptionSchedule).to receive(:release).with("sub_sched_789").and_return(true)

    sign_in user, scope: :user

    post dashboard_cancel_scheduled_downgrade_path

    expect(response).to redirect_to(dashboard_plans_path)
    expect(flash[:notice]).to eq(I18n.t("dashboard.plans.cancel_success"))

    subscription.reload
    expect(subscription.metadata).not_to include("scheduled_plan_key")
  end

  it "retries upgrade after releasing a managed schedule" do
    subscription = customer.subscriptions.create!(
      name: "default",
      processor_id: "sub_#{SecureRandom.hex(4)}",
      processor_plan: monthly_plan.stripe_price_id,
      status: "active",
      quantity: 1,
      current_period_start: Time.current,
      current_period_end: 1.month.from_now,
      metadata: { "scheduled_schedule_id" => "sub_sched_active" },
      type: "Pay::Stripe::Subscription"
    )

    allow(Stripe::Subscription).to receive(:retrieve).and_return(double(schedule: "sub_sched_active"))
    allow(Stripe::SubscriptionSchedule).to receive(:retrieve).and_return(double(status: "active"))
    expect(Stripe::SubscriptionSchedule).to receive(:release).with("sub_sched_active").at_least(:once)

    swap_calls = 0
    allow_any_instance_of(Pay::Stripe::Subscription).to receive(:swap) do
      swap_calls += 1
      raise Pay::Stripe::Error.new("The subscription is managed by the subscription schedule") if swap_calls == 1

      true
    end

    sign_in user, scope: :user

    post dashboard_checkout_path, params: { price_key: Billing::PandoraPricing::ANNUAL_KEY }

    expect(response).to redirect_to(dashboard_plans_path)
  end

  it "retries upgrade after a deadlock" do
    subscription = customer.subscriptions.create!(
      name: "default",
      processor_id: "sub_#{SecureRandom.hex(4)}",
      processor_plan: monthly_plan.stripe_price_id,
      status: "active",
      quantity: 1,
      current_period_start: Time.current,
      current_period_end: 1.month.from_now,
      type: "Pay::Stripe::Subscription"
    )

    allow_any_instance_of(Pay::Stripe::Subscription).to receive(:sync!).and_return(false)

    swap_calls = 0
    allow_any_instance_of(Pay::Stripe::Subscription).to receive(:swap) do
      swap_calls += 1
      raise ActiveRecord::Deadlocked if swap_calls == 1

      true
    end

    sign_in user, scope: :user

    post dashboard_checkout_path, params: { price_key: Billing::PandoraPricing::ANNUAL_KEY }

    expect(response).to redirect_to(dashboard_plans_path)
    expect(flash[:notice]).to eq(I18n.t("dashboard.billing.upgraded"))
  end

  it "returns success after a deadlock if Stripe already upgraded" do
    subscription = customer.subscriptions.create!(
      name: "default",
      processor_id: "sub_#{SecureRandom.hex(4)}",
      processor_plan: monthly_plan.stripe_price_id,
      status: "active",
      quantity: 1,
      current_period_start: Time.current,
      current_period_end: 1.month.from_now,
      type: "Pay::Stripe::Subscription"
    )

    expect_any_instance_of(Pay::Stripe::Subscription).to receive(:swap).once.and_raise(ActiveRecord::Deadlocked)
    allow_any_instance_of(Pay::Stripe::Subscription).to receive(:sync!) do |record|
      record.update!(processor_plan: annual_plan.stripe_price_id)
      true
    end

    sign_in user, scope: :user

    post dashboard_checkout_path, params: { price_key: Billing::PandoraPricing::ANNUAL_KEY }

    expect(response).to redirect_to(dashboard_plans_path)
    expect(flash[:notice]).to eq(I18n.t("dashboard.billing.upgraded"))
  end

  it "ignores missing schedules when releasing during upgrade" do
    subscription = customer.subscriptions.create!(
      name: "default",
      processor_id: "sub_#{SecureRandom.hex(4)}",
      processor_plan: monthly_plan.stripe_price_id,
      status: "active",
      quantity: 1,
      current_period_start: Time.current,
      current_period_end: 1.month.from_now,
      metadata: { "scheduled_schedule_id" => "sub_sched_missing" },
      type: "Pay::Stripe::Subscription"
    )

    allow(Stripe::Subscription).to receive(:retrieve).and_return(double(schedule: "sub_sched_missing"))
    allow(Stripe::SubscriptionSchedule).to receive(:retrieve).and_return(nil)
    expect(Stripe::SubscriptionSchedule).to receive(:release)
      .with("sub_sched_missing")
      .and_raise(Stripe::InvalidRequestError.new("No such subscription schedule", nil))

    expect_any_instance_of(Pay::Stripe::Subscription)
      .to receive(:swap)
      .with(annual_plan.stripe_price_id, hash_including(proration_behavior: "always_invoice"))
      .and_return(true)

    sign_in user, scope: :user

    post dashboard_checkout_path, params: { price_key: Billing::PandoraPricing::ANNUAL_KEY }

    expect(response).to redirect_to(dashboard_plans_path)
  end

  it "clears scheduled metadata when Stripe shows a released schedule" do
    subscription = customer.subscriptions.create!(
      name: "default",
      processor_id: "sub_#{SecureRandom.hex(4)}",
      processor_plan: annual_plan.stripe_price_id,
      status: "active",
      quantity: 1,
      current_period_start: Time.current,
      current_period_end: 1.month.from_now,
      metadata: {
        "scheduled_plan_key" => Billing::PandoraPricing::MONTHLY_KEY,
        "scheduled_schedule_id" => "sub_sched_released",
        "scheduled_change_at" => 1.month.from_now.iso8601
      },
      type: "Pay::Stripe::Subscription"
    )

    allow(Stripe::SubscriptionSchedule).to receive(:retrieve)
      .with("sub_sched_released")
      .and_return(double(status: "released"))

    sign_in user, scope: :user

    get dashboard_plans_path

    expect(response).to be_successful
    subscription.reload
    expect(subscription.metadata).not_to include("scheduled_plan_key")
  end

  it "clears scheduled metadata when Stripe schedule is missing" do
    subscription = customer.subscriptions.create!(
      name: "default",
      processor_id: "sub_#{SecureRandom.hex(4)}",
      processor_plan: annual_plan.stripe_price_id,
      status: "active",
      quantity: 1,
      current_period_start: Time.current,
      current_period_end: 1.month.from_now,
      metadata: {
        "scheduled_plan_key" => Billing::PandoraPricing::MONTHLY_KEY,
        "scheduled_schedule_id" => "sub_sched_missing",
        "scheduled_change_at" => 1.month.from_now.iso8601
      },
      type: "Pay::Stripe::Subscription"
    )

    allow(Stripe::SubscriptionSchedule).to receive(:retrieve)
      .with("sub_sched_missing")
      .and_raise(Stripe::InvalidRequestError.new("No such subscription schedule", nil))

    sign_in user, scope: :user

    get dashboard_plans_path

    expect(response).to be_successful

    subscription.reload
    expect(subscription.metadata).not_to include("scheduled_plan_key")
  end

  it "prefers the most recent active subscription for display" do
    older = customer.subscriptions.create!(
      name: "default",
      processor_id: "sub_#{SecureRandom.hex(4)}",
      processor_plan: monthly_plan.stripe_price_id,
      status: "active",
      quantity: 1,
      current_period_start: 2.months.ago,
      current_period_end: 1.month.from_now,
      created_at: 2.days.ago,
      type: "Pay::Stripe::Subscription"
    )

    newer = customer.subscriptions.create!(
      name: "default",
      processor_id: "sub_#{SecureRandom.hex(4)}",
      processor_plan: annual_plan.stripe_price_id,
      status: "active",
      quantity: 1,
      current_period_start: Time.current,
      current_period_end: 1.month.from_now,
      created_at: Time.current,
      type: "Pay::Stripe::Subscription"
    )

    sign_in user, scope: :user

    get dashboard_path

    expect(response).to be_successful
    plan_label = I18n.t(
      "dashboard.plan_card.plan_label",
      tier: I18n.t("dashboard.plans.tiers.pandora_pro.name"),
      interval: I18n.t("dashboard.plans.toggle.annually")
    )
    expect(response.body).to include(plan_label)
  end

  it "adds an upgrade confirmation when upgrades are available" do
    customer.subscriptions.create!(
      name: "default",
      processor_id: "sub_#{SecureRandom.hex(4)}",
      processor_plan: monthly_plan.stripe_price_id,
      status: "active",
      quantity: 1,
      current_period_start: Time.current,
      current_period_end: 1.month.from_now,
      type: "Pay::Stripe::Subscription"
    )

    sign_in user, scope: :user

    get dashboard_plans_path

    confirm_text = I18n.t("dashboard.plans.upgrade_confirm")
    expect(response).to be_successful
    expect(response.body).to include("data-confirm-message")
    expect(response.body).to include(confirm_text)
  end

  it "omits upgrade confirmation when no upgrades are available" do
    customer.subscriptions.create!(
      name: "default",
      processor_id: "sub_#{SecureRandom.hex(4)}",
      processor_plan: annual_plan.stripe_price_id,
      status: "active",
      quantity: 1,
      current_period_start: Time.current,
      current_period_end: 1.month.from_now,
      type: "Pay::Stripe::Subscription"
    )

    sign_in user, scope: :user

    get dashboard_plans_path

    expect(response).to be_successful
    expect(response.body).not_to include(I18n.t("dashboard.plans.upgrade_confirm"))
  end
end
