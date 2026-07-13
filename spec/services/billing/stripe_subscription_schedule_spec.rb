require "rails_helper"
require "ostruct"

RSpec.describe Billing::StripeSubscriptionSchedule do
  around do |example|
    original_key = ENV["STRIPE_PRIVATE_KEY"]
    ENV["STRIPE_PRIVATE_KEY"] = "stripe_test_key"
    example.run
  ensure
    ENV["STRIPE_PRIVATE_KEY"] = original_key
  end

  it "creates a no-proration transition that preserves the current phase and quantity" do
    subscription = create_subscription(quantity: 3)
    effective_at = subscription.current_period_end
    allow(Stripe::Subscription).to receive(:retrieve).with(subscription.processor_id).and_return(OpenStruct.new(schedule: nil))
    expect(Stripe::SubscriptionSchedule).to receive(:create).with(
      { from_subscription: subscription.processor_id },
      hash_including(idempotency_key: a_string_including("pandora-catalog"))
    ).and_return(OpenStruct.new(id: "sub_sched_catalog"))
    allow(Stripe::SubscriptionSchedule).to receive(:update) do |schedule_id, params|
      expect(schedule_id).to eq("sub_sched_catalog")
      expect(params[:end_behavior]).to eq("release")
      expect(params[:phases]).to eq(
        [
          {
            items: [ { price: subscription.processor_plan, quantity: 3 } ],
            start_date: subscription.current_period_start.to_i,
            end_date: effective_at.to_i
          },
          {
            items: [ { price: "price_pandora_annual", quantity: 3 } ],
            start_date: effective_at.to_i
          }
        ]
      )
      schedule_from(schedule_id:, params:)
    end

    result = described_class.new(subscription: subscription).schedule_catalog_transition(
      target_price_id: "price_pandora_annual",
      target_plan_key: Billing::PandoraPricing::ANNUAL_KEY,
      effective_at: effective_at,
      migration_key: Billing::LegacySubscriptionMigrator::MIGRATION_KEY
    )

    expect(result.created).to be(true)
    expect(result.schedule.id).to eq("sub_sched_catalog")
  end

  it "reuses a matching managed schedule without creating another" do
    subscription = create_subscription
    effective_at = subscription.current_period_end
    metadata = catalog_metadata(subscription:, effective_at:)
    existing = schedule_from(
      schedule_id: "sub_sched_existing",
      params: {
        metadata: metadata,
        phases: phases_for(subscription:, effective_at:)
      }
    )
    allow(Stripe::Subscription).to receive(:retrieve).and_return(OpenStruct.new(schedule: existing.id))
    allow(Stripe::SubscriptionSchedule).to receive(:retrieve).with(existing.id).and_return(existing)
    expect(Stripe::SubscriptionSchedule).not_to receive(:create)
    allow(Stripe::SubscriptionSchedule).to receive(:update).and_return(existing)

    result = described_class.new(subscription: subscription).schedule_catalog_transition(
      target_price_id: "price_pandora_annual",
      target_plan_key: Billing::PandoraPricing::ANNUAL_KEY,
      effective_at: effective_at,
      migration_key: Billing::LegacySubscriptionMigrator::MIGRATION_KEY
    )

    expect(result.created).to be(false)
    expect(result.schedule.id).to eq(existing.id)
  end

  it "rejects an unmanaged Stripe schedule instead of overwriting it" do
    subscription = create_subscription
    unmanaged = OpenStruct.new(id: "sub_sched_other", status: "active", metadata: { "managed_by" => "operator" }, phases: [])
    allow(Stripe::Subscription).to receive(:retrieve).and_return(OpenStruct.new(schedule: unmanaged.id))
    allow(Stripe::SubscriptionSchedule).to receive(:retrieve).with(unmanaged.id).and_return(unmanaged)
    expect(Stripe::SubscriptionSchedule).not_to receive(:create)
    expect(Stripe::SubscriptionSchedule).not_to receive(:update)

    expect do
      described_class.new(subscription: subscription).schedule_catalog_transition(
        target_price_id: "price_pandora_annual",
        target_plan_key: Billing::PandoraPricing::ANNUAL_KEY,
        effective_at: subscription.current_period_end,
        migration_key: Billing::LegacySubscriptionMigrator::MIGRATION_KEY
      )
    end.to raise_error(Billing::StripeSubscriptionSchedule::ConflictingScheduleError, /sub_legacy/)
  end

  it "recovers the exact idempotent schedule when creation succeeded before metadata was applied" do
    subscription = create_subscription
    effective_at = subscription.current_period_end
    pending = OpenStruct.new(id: "sub_sched_pending", status: "active", metadata: {}, phases: [])
    allow(Stripe::Subscription).to receive(:retrieve).and_return(OpenStruct.new(schedule: pending.id))
    allow(Stripe::SubscriptionSchedule).to receive(:retrieve).with(pending.id).and_return(pending)
    expect(Stripe::SubscriptionSchedule).to receive(:create).with(
      { from_subscription: subscription.processor_id },
      hash_including(idempotency_key: a_string_including("pandora-catalog"))
    ).and_return(pending)
    allow(Stripe::SubscriptionSchedule).to receive(:update) do |schedule_id, params|
      schedule_from(schedule_id: schedule_id, params: params)
    end

    result = described_class.new(subscription: subscription).schedule_catalog_transition(
      target_price_id: "price_pandora_annual",
      target_plan_key: Billing::PandoraPricing::ANNUAL_KEY,
      effective_at: effective_at,
      migration_key: Billing::LegacySubscriptionMigrator::MIGRATION_KEY
    )

    expect(result.created).to be(false)
    expect(result.schedule.id).to eq(pending.id)
  end

  def create_subscription(quantity: 1)
    user = create(:user)
    customer = user.pay_customers.create!(processor: "stripe", processor_id: "cus_legacy", default: true)
    customer.subscriptions.create!(
      name: "default",
      processor_id: "sub_legacy",
      processor_plan: "price_legacy_monthly",
      status: "active",
      quantity: quantity,
      current_period_start: 1.day.ago,
      current_period_end: 29.days.from_now,
      type: "Pay::Stripe::Subscription"
    )
  end

  def catalog_metadata(subscription:, effective_at:)
    {
      "managed_by" => described_class::CATALOG_MANAGED_BY,
      "migration_key" => Billing::LegacySubscriptionMigrator::MIGRATION_KEY,
      "pay_subscription_id" => subscription.id.to_s,
      "source_price_id" => subscription.processor_plan,
      "target_plan_key" => Billing::PandoraPricing::ANNUAL_KEY,
      "target_price_id" => "price_pandora_annual",
      "effective_at" => effective_at.to_i.to_s
    }
  end

  def phases_for(subscription:, effective_at:)
    [
      {
        items: [ { price: subscription.processor_plan, quantity: subscription.quantity } ],
        start_date: subscription.current_period_start.to_i,
        end_date: effective_at.to_i
      },
      {
        items: [ { price: "price_pandora_annual", quantity: subscription.quantity } ],
        start_date: effective_at.to_i
      }
    ]
  end

  def schedule_from(schedule_id:, params:)
    OpenStruct.new(
      id: schedule_id,
      status: "active",
      metadata: params.fetch(:metadata),
      phases: params.fetch(:phases)
    )
  end
end
