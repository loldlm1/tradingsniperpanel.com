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

  around do |example|
    original_env = ENV.to_hash
    ENV["STRIPE_PRICE_BASIC_MONTHLY"] = "price_basic_monthly"
    ENV["STRIPE_PRICE_HFT_MONTHLY"] = "price_hft_monthly"
    ENV["STRIPE_PRICE_PRO_MONTHLY"] = "price_pro_monthly"
    ENV["STRIPE_PRIVATE_KEY"] = "sk_test_123"
    example.run
  ensure
    ENV.replace(original_env)
  end

  before do
    allow(Stripe::Subscription).to receive(:retrieve).and_return(double(schedule: nil))
    allow(Stripe::SubscriptionSchedule).to receive(:retrieve).and_return(double(status: "active"))
  end

  it "swaps an existing subscription instead of creating a new one" do
    existing = customer.subscriptions.create!(
      name: "default",
      processor_id: "sub_#{SecureRandom.hex(4)}",
      processor_plan: ENV["STRIPE_PRICE_BASIC_MONTHLY"],
      status: "active",
      quantity: 1,
      current_period_start: Time.current,
      current_period_end: 1.month.from_now,
      type: "Pay::Stripe::Subscription"
    )

    expect_any_instance_of(Pay::Stripe::Subscription).to receive(:swap).with("price_hft_monthly", hash_including(proration_behavior: "always_invoice")).and_return(true)

    sign_in user, scope: :user

    post dashboard_checkout_path, params: { price_key: "hft_monthly" }

    expect(response).to redirect_to(dashboard_plans_path)
    expect(flash[:notice]).to eq(I18n.t("dashboard.billing.upgraded"))
  end

  it "schedules a downgrade at period end for lower-priced plans" do
    subscription = customer.subscriptions.create!(
      name: "default",
      processor_id: "sub_#{SecureRandom.hex(4)}",
      processor_plan: ENV["STRIPE_PRICE_HFT_MONTHLY"],
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

    post dashboard_checkout_path, params: { price_key: "basic_monthly" }

    expect(response).to redirect_to(dashboard_plans_path)

    subscription.reload
    expect(subscription.metadata["scheduled_plan_key"]).to eq("basic_monthly")
    expect(subscription.metadata["scheduled_schedule_id"]).to eq("sub_sched_123")
    expect(subscription.metadata["scheduled_change_at"]).to be_present
  end

  it "updates an existing Stripe schedule when metadata is missing" do
    subscription = customer.subscriptions.create!(
      name: "default",
      processor_id: "sub_#{SecureRandom.hex(4)}",
      processor_plan: ENV["STRIPE_PRICE_HFT_MONTHLY"],
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

    post dashboard_checkout_path, params: { price_key: "basic_monthly" }

    expect(response).to redirect_to(dashboard_plans_path)

    subscription.reload
    expect(subscription.metadata["scheduled_schedule_id"]).to eq("sub_sched_existing")
  end

  it "creates a new schedule when the existing one is released" do
    subscription = customer.subscriptions.create!(
      name: "default",
      processor_id: "sub_#{SecureRandom.hex(4)}",
      processor_plan: ENV["STRIPE_PRICE_HFT_MONTHLY"],
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

    post dashboard_checkout_path, params: { price_key: "basic_monthly" }

    expect(response).to redirect_to(dashboard_plans_path)

    subscription.reload
    expect(subscription.metadata["scheduled_schedule_id"]).to eq("sub_sched_new")
  end

  it "backfills scheduled change details from Stripe when metadata is missing" do
    subscription = customer.subscriptions.create!(
      name: "default",
      processor_id: "sub_#{SecureRandom.hex(4)}",
      processor_plan: ENV["STRIPE_PRICE_HFT_MONTHLY"],
      status: "active",
      quantity: 1,
      current_period_start: Time.current,
      current_period_end: 1.month.from_now,
      type: "Pay::Stripe::Subscription"
    )

    phase = double(start_date: 1.month.from_now.to_i, items: [double(price: "price_basic_monthly")])
    schedule = double(id: "sub_sched_backfill", phases: [phase])
    allow(Stripe::Subscription).to receive(:retrieve).and_return(double(schedule: "sub_sched_backfill"))
    allow(Stripe::SubscriptionSchedule).to receive(:retrieve).and_return(schedule)

    sign_in user, scope: :user

    get dashboard_plans_path

    expect(response).to be_successful
    expect(response.body).to include(I18n.t("dashboard.plans.scheduled_badge"))

    subscription.reload
    expect(subscription.metadata["scheduled_plan_key"]).to eq("basic_monthly")
  end

  it "releases a scheduled downgrade when upgrading" do
    subscription = customer.subscriptions.create!(
      name: "default",
      processor_id: "sub_#{SecureRandom.hex(4)}",
      processor_plan: ENV["STRIPE_PRICE_HFT_MONTHLY"],
      status: "active",
      quantity: 1,
      current_period_start: Time.current,
      current_period_end: 1.month.from_now,
      metadata: {
        "scheduled_plan_key" => "basic_monthly",
        "scheduled_schedule_id" => "sub_sched_789",
        "scheduled_change_at" => 1.month.from_now.iso8601
      },
      type: "Pay::Stripe::Subscription"
    )

    allow(Stripe::SubscriptionSchedule).to receive(:release).and_return(true)
    expect(Stripe::SubscriptionSchedule).to receive(:release).with("sub_sched_789")
    expect_any_instance_of(Pay::Stripe::Subscription).to receive(:swap).with("price_pro_monthly", hash_including(proration_behavior: "always_invoice")).and_return(true)

    sign_in user, scope: :user

    post dashboard_checkout_path, params: { price_key: "pro_monthly" }

    expect(response).to redirect_to(dashboard_plans_path)

    subscription.reload
    expect(subscription.metadata).not_to include("scheduled_plan_key")
  end

  it "cancels a scheduled downgrade from the plans page" do
    subscription = customer.subscriptions.create!(
      name: "default",
      processor_id: "sub_#{SecureRandom.hex(4)}",
      processor_plan: ENV["STRIPE_PRICE_HFT_MONTHLY"],
      status: "active",
      quantity: 1,
      current_period_start: Time.current,
      current_period_end: 1.month.from_now,
      metadata: {
        "scheduled_plan_key" => "basic_monthly",
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
      processor_plan: ENV["STRIPE_PRICE_HFT_MONTHLY"],
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

    post dashboard_checkout_path, params: { price_key: "pro_monthly" }

    expect(response).to redirect_to(dashboard_plans_path)
  end

  it "retries upgrade after a deadlock" do
    subscription = customer.subscriptions.create!(
      name: "default",
      processor_id: "sub_#{SecureRandom.hex(4)}",
      processor_plan: ENV["STRIPE_PRICE_BASIC_MONTHLY"],
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

    post dashboard_checkout_path, params: { price_key: "hft_monthly" }

    expect(response).to redirect_to(dashboard_plans_path)
    expect(flash[:notice]).to eq(I18n.t("dashboard.billing.upgraded"))
  end

  it "returns success after a deadlock if Stripe already upgraded" do
    subscription = customer.subscriptions.create!(
      name: "default",
      processor_id: "sub_#{SecureRandom.hex(4)}",
      processor_plan: ENV["STRIPE_PRICE_BASIC_MONTHLY"],
      status: "active",
      quantity: 1,
      current_period_start: Time.current,
      current_period_end: 1.month.from_now,
      type: "Pay::Stripe::Subscription"
    )

    expect_any_instance_of(Pay::Stripe::Subscription).to receive(:swap).once.and_raise(ActiveRecord::Deadlocked)
    allow_any_instance_of(Pay::Stripe::Subscription).to receive(:sync!) do |record|
      record.update!(processor_plan: "price_hft_monthly")
      true
    end

    sign_in user, scope: :user

    post dashboard_checkout_path, params: { price_key: "hft_monthly" }

    expect(response).to redirect_to(dashboard_plans_path)
    expect(flash[:notice]).to eq(I18n.t("dashboard.billing.upgraded"))
  end

  it "ignores missing schedules when releasing during upgrade" do
    subscription = customer.subscriptions.create!(
      name: "default",
      processor_id: "sub_#{SecureRandom.hex(4)}",
      processor_plan: ENV["STRIPE_PRICE_HFT_MONTHLY"],
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
      .with("price_pro_monthly", hash_including(proration_behavior: "always_invoice"))
      .and_return(true)

    sign_in user, scope: :user

    post dashboard_checkout_path, params: { price_key: "pro_monthly" }

    expect(response).to redirect_to(dashboard_plans_path)
  end

  it "clears scheduled metadata when Stripe shows a released schedule" do
    subscription = customer.subscriptions.create!(
      name: "default",
      processor_id: "sub_#{SecureRandom.hex(4)}",
      processor_plan: ENV["STRIPE_PRICE_HFT_MONTHLY"],
      status: "active",
      quantity: 1,
      current_period_start: Time.current,
      current_period_end: 1.month.from_now,
      metadata: {
        "scheduled_plan_key" => "basic_monthly",
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
      processor_plan: ENV["STRIPE_PRICE_HFT_MONTHLY"],
      status: "active",
      quantity: 1,
      current_period_start: Time.current,
      current_period_end: 1.month.from_now,
      metadata: {
        "scheduled_plan_key" => "basic_monthly",
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
      processor_plan: ENV["STRIPE_PRICE_BASIC_MONTHLY"],
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
      processor_plan: ENV["STRIPE_PRICE_HFT_MONTHLY"],
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
    expect(response.body).to include("Plan key: hft_monthly")
  end
end
