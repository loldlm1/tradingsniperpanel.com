require "rails_helper"

RSpec.describe Billing::PlanChange do
  TRANSITIONS = {
    Billing::ChuSniperPricing::MONTHLY_KEY => {
      Billing::ChuSniperPricing::MONTHLY_KEY => :current,
      Billing::ChuSniperPricing::ANNUAL_KEY => :upgrade,
      Billing::PandoraPricing::MONTHLY_KEY => :upgrade,
      Billing::PandoraPricing::ANNUAL_KEY => :upgrade
    },
    Billing::ChuSniperPricing::ANNUAL_KEY => {
      Billing::ChuSniperPricing::MONTHLY_KEY => :downgrade,
      Billing::ChuSniperPricing::ANNUAL_KEY => :current,
      Billing::PandoraPricing::MONTHLY_KEY => :upgrade,
      Billing::PandoraPricing::ANNUAL_KEY => :upgrade
    },
    Billing::PandoraPricing::MONTHLY_KEY => {
      Billing::ChuSniperPricing::MONTHLY_KEY => :downgrade,
      Billing::ChuSniperPricing::ANNUAL_KEY => :downgrade,
      Billing::PandoraPricing::MONTHLY_KEY => :current,
      Billing::PandoraPricing::ANNUAL_KEY => :upgrade
    },
    Billing::PandoraPricing::ANNUAL_KEY => {
      Billing::ChuSniperPricing::MONTHLY_KEY => :downgrade,
      Billing::ChuSniperPricing::ANNUAL_KEY => :downgrade,
      Billing::PandoraPricing::MONTHLY_KEY => :downgrade,
      Billing::PandoraPricing::ANNUAL_KEY => :current
    }
  }.freeze

  let!(:catalog) { create_subscription_catalog }
  let(:user) { create(:user) }

  TRANSITIONS.each do |current_key, targets|
    targets.each do |target_key, expected_direction|
      it "applies #{current_key} -> #{target_key} as #{expected_direction}" do
        current_plan = catalog[:plans].fetch(current_key)
        target_plan = catalog[:plans].fetch(target_key)
        effective_at = 1.month.from_now.change(usec: 0)
        subscription = build_subscription(current_plan:, effective_at:)
        scheduled_change = instance_double(Billing::ScheduledPlanChange)
        stripe_schedule = instance_double(Billing::StripeSubscriptionSchedule)

        allow(Billing::ScheduledPlanChange).to receive(:new).and_return(scheduled_change)
        allow(Billing::StripeSubscriptionSchedule).to receive(:new).and_return(stripe_schedule)

        result = case expected_direction
        when :current
          expect(subscription).not_to receive(:swap)
          expect(stripe_schedule).not_to receive(:schedule_downgrade)
          described_class.new(subscription:, price_key: target_key, user:).call
        when :upgrade
          allow(stripe_schedule).to receive(:managed_schedule_id)
          expect(subscription).to receive(:swap)
            .with(target_plan.stripe_price_id, proration_behavior: "always_invoice")
            .and_return(true)
          expect(stripe_schedule).not_to receive(:schedule_downgrade)
          described_class.new(subscription:, price_key: target_key, user:).call
        when :downgrade
          schedule = double(id: "schedule_#{current_plan.id}_#{target_plan.id}")
          verified = { price_key: target_key, effective_at: effective_at, schedule_id: schedule.id }
          allow(scheduled_change).to receive(:fetch).and_return(nil, verified)
          expect(scheduled_change).to receive(:store!).with(
            price_key: target_key,
            schedule_id: schedule.id,
            effective_at: effective_at
          )
          expect(stripe_schedule).to receive(:schedule_downgrade)
            .with(target_price_id: target_plan.stripe_price_id, effective_at: effective_at)
            .and_return(schedule)
          expect(subscription).not_to receive(:swap)
          described_class.new(subscription:, price_key: target_key, user:).call
        end

        expected_status = {
          current: :already_current,
          upgrade: :upgraded,
          downgrade: :downgrade_scheduled
        }.fetch(expected_direction)
        expect(result.status).to eq(expected_status)
      end
    end
  end

  private

  def build_subscription(current_plan:, effective_at:)
    double(
      id: current_plan.id,
      processor_plan: current_plan.stripe_price_id,
      current_period_end: effective_at,
      metadata: {},
      reload: true,
      with_lock: nil
    ).tap do |subscription|
      allow(subscription).to receive(:with_lock) { |&block| block.call }
    end
  end
end
