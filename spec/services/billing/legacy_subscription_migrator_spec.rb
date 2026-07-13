require "rails_helper"
require "ostruct"

RSpec.describe Billing::LegacySubscriptionMigrator do
  before do
    create_pandora_plans
    allow(Stripe::Subscription).to receive(:update) do |_processor_id, params|
      OpenStruct.new(metadata: params.fetch(:metadata))
    end
  end

  it "schedules an interval-matched annual transition and persists retry markers" do
    subscription = create_legacy_subscription(interval: "year")
    schedule = instance_double(Billing::StripeSubscriptionSchedule)
    transition = Billing::StripeSubscriptionSchedule::CatalogTransition.new(
      schedule: OpenStruct.new(id: "sub_sched_annual"),
      created: true
    )
    expect(schedule).to receive(:schedule_catalog_transition).with(
      target_price_id: "price_pandora_annual",
      target_plan_key: Billing::PandoraPricing::ANNUAL_KEY,
      effective_at: subscription.current_period_end,
      migration_key: described_class::MIGRATION_KEY
    ).and_return(transition)
    allow(schedule).to receive(:verify_catalog_transition).and_return(true)
    remote_metadata = nil
    allow(Stripe::Subscription).to receive(:update) do |processor_id, params|
      expect(processor_id).to eq(subscription.processor_id)
      remote_metadata = params.fetch(:metadata).stringify_keys
      OpenStruct.new(metadata: remote_metadata)
    end
    service = described_class.new(
      schedule_factory: ->(_record) { schedule },
      subscription_scope: Pay::Subscription.where(id: subscription.id),
      now: Time.zone.parse("2026-07-13 12:00:00")
    )

    result = service.call

    expect(result.scheduled).to eq(1)
    metadata = subscription.reload.metadata
    expect(metadata[described_class::METADATA_KEYS.fetch(:migration)]).to eq(described_class::MIGRATION_KEY)
    expect(metadata[described_class::METADATA_KEYS.fetch(:target_plan)]).to eq(Billing::PandoraPricing::ANNUAL_KEY)
    expect(metadata[described_class::METADATA_KEYS.fetch(:schedule)]).to eq("sub_sched_annual")
    expect(metadata["scheduled_schedule_id"]).to eq("sub_sched_annual")
    expect(remote_metadata).to include(
      described_class::METADATA_KEYS.fetch(:migration) => described_class::MIGRATION_KEY,
      described_class::METADATA_KEYS.fetch(:target_plan) => Billing::PandoraPricing::ANNUAL_KEY,
      described_class::METADATA_KEYS.fetch(:schedule) => "sub_sched_annual"
    )

    subscription.update!(metadata: remote_metadata)
    expect(service.verify!).to be(true)
  end

  it "observes the same managed schedule on a retry without changing the original marker time" do
    subscription = create_legacy_subscription(interval: "month")
    calls = 0
    schedule = instance_double(Billing::StripeSubscriptionSchedule)
    allow(schedule).to receive(:schedule_catalog_transition) do
      calls += 1
      Billing::StripeSubscriptionSchedule::CatalogTransition.new(
        schedule: OpenStruct.new(id: "sub_sched_monthly"),
        created: calls == 1
      )
    end
    service = described_class.new(
      schedule_factory: ->(_record) { schedule },
      subscription_scope: Pay::Subscription.where(id: subscription.id),
      now: Time.zone.parse("2026-07-13 12:00:00")
    )

    first = service.call
    first_scheduled_at = subscription.reload.metadata[described_class::METADATA_KEYS.fetch(:scheduled_at)]
    second = service.call

    expect(first.scheduled).to eq(1)
    expect(second.verified).to eq(1)
    expect(subscription.reload.metadata[described_class::METADATA_KEYS.fetch(:scheduled_at)]).to eq(first_scheduled_at)
  end

  it "propagates a conflicting schedule without persisting migration metadata" do
    subscription = create_legacy_subscription(interval: "month")
    schedule = instance_double(Billing::StripeSubscriptionSchedule)
    allow(schedule).to receive(:schedule_catalog_transition)
      .and_raise(Billing::StripeSubscriptionSchedule::ConflictingScheduleError, "conflicting schedule")
    service = described_class.new(
      schedule_factory: ->(_record) { schedule },
      subscription_scope: Pay::Subscription.where(id: subscription.id)
    )

    expect { service.call }.to raise_error(Billing::StripeSubscriptionSchedule::ConflictingScheduleError)
    expect(subscription.reload.metadata.to_h).not_to include(described_class::METADATA_KEYS.fetch(:migration))
  end

  it "fails closed when Stripe subscription metadata cannot be persisted" do
    subscription = create_legacy_subscription(interval: "month")
    schedule = instance_double(Billing::StripeSubscriptionSchedule)
    transition = Billing::StripeSubscriptionSchedule::CatalogTransition.new(
      schedule: OpenStruct.new(id: "sub_sched_monthly"),
      created: false
    )
    allow(schedule).to receive(:schedule_catalog_transition).and_return(transition)
    allow(Stripe::Subscription).to receive(:update).and_raise(StandardError, "metadata update failed")
    service = described_class.new(
      schedule_factory: ->(_record) { schedule },
      subscription_scope: Pay::Subscription.where(id: subscription.id)
    )

    expect { service.call }.to raise_error(StandardError, "metadata update failed")
    expect(subscription.reload.metadata.to_h).not_to include(described_class::METADATA_KEYS.fetch(:migration))
  end

  it "fails closed for a legacy interval that cannot map to monthly or annual" do
    subscription = create_legacy_subscription(interval: "week")
    service = described_class.new(
      schedule_factory: ->(_record) { raise "schedule should not be called" },
      subscription_scope: Pay::Subscription.where(id: subscription.id)
    )

    expect { service.call }.to raise_error(RuntimeError, /Unsupported legacy interval/)
  end

  it "does not schedule a subscription already ending at the current period end" do
    subscription = create_legacy_subscription(interval: "month")
    subscription.update!(ends_at: subscription.current_period_end)
    service = described_class.new(
      schedule_factory: ->(_record) { raise "schedule should not be called" },
      subscription_scope: Pay::Subscription.where(id: subscription.id)
    )

    result = service.call

    expect(result.canceling).to eq(1)
    expect(subscription.reload.metadata.to_h).to be_empty
  end

  def create_pandora_plans
    create(
      :billing_plan,
      key: Billing::PandoraPricing::MONTHLY_KEY,
      name: "Pandora Box EA Monthly",
      tier: Billing::PandoraPricing::TIER,
      interval: "month",
      interval_count: 1,
      amount_cents: Billing::PandoraPricing::MONTHLY_CENTS,
      currency: Billing::PandoraPricing::CURRENCY,
      stripe_product_id: "prod_pandora",
      stripe_price_id: "price_pandora_monthly"
    )
    create(
      :billing_plan,
      key: Billing::PandoraPricing::ANNUAL_KEY,
      name: "Pandora Box EA Annual",
      tier: Billing::PandoraPricing::TIER,
      interval: "year",
      interval_count: 1,
      amount_cents: Billing::PandoraPricing::ANNUAL_CENTS,
      currency: Billing::PandoraPricing::CURRENCY,
      stripe_product_id: "prod_pandora",
      stripe_price_id: "price_pandora_annual"
    )
  end

  def create_legacy_subscription(interval:)
    interval_key = Billing::IntervalLabeler.interval_key(interval: interval, interval_count: 1)
    plan = create(
      :billing_plan,
      key: "legacy_#{interval_key}",
      name: "Legacy #{interval_key}",
      tier: "legacy",
      interval: interval,
      interval_count: 1,
      stripe_price_id: "price_legacy_#{interval_key}"
    )
    create(
      :billing_plan_price,
      billing_plan: plan,
      stripe_price_id: plan.stripe_price_id,
      interval: interval,
      interval_count: 1,
      current: true
    )
    user = create(:user)
    customer = user.pay_customers.create!(processor: "stripe", processor_id: "cus_#{interval_key}", default: true)
    customer.subscriptions.create!(
      name: "default",
      processor_id: "sub_legacy_#{interval_key}",
      processor_plan: plan.stripe_price_id,
      status: "active",
      quantity: 1,
      current_period_start: 1.day.ago,
      current_period_end: 29.days.from_now,
      metadata: {},
      type: "Pay::Stripe::Subscription"
    )
  end
end
