require "rails_helper"
require "securerandom"

RSpec.describe Licenses::PaySubscriptionCallbacks do
  include ActiveJob::TestHelper

  let(:user) { create(:user) }

  before do
    clear_enqueued_jobs
  end

  after do
    clear_enqueued_jobs
  end

  it "enqueues a license sync when a Pay subscription is saved" do
    customer = user.pay_customers.create!(
      processor: "stripe",
      processor_id: "cus_#{SecureRandom.hex(4)}",
      default: true
    )

    expect do
      customer.subscriptions.create!(
        name: "default",
        processor_id: "sub_#{SecureRandom.hex(4)}",
        processor_plan: "price_basic_monthly",
        status: "active",
        quantity: 1,
        current_period_start: Time.current,
        current_period_end: 1.month.from_now
      )
    end.to have_enqueued_job(Licenses::SyncSubscriptionJob)
  end

  it "cancels other active subscriptions for the same customer" do
    customer = user.pay_customers.create!(
      processor: "stripe",
      processor_id: "cus_#{SecureRandom.hex(4)}",
      default: true
    )

    existing = customer.subscriptions.create!(
      name: "default",
      processor_id: "sub_#{SecureRandom.hex(4)}",
      processor_plan: "price_basic_monthly",
      status: "active",
      quantity: 1,
      current_period_start: Time.current,
      current_period_end: 1.month.from_now,
      type: "Pay::Stripe::Subscription"
    )

    expect_any_instance_of(Pay::Stripe::Subscription).to receive(:cancel_now!).at_least(:once).and_return(true)

    expect do
      customer.subscriptions.create!(
        name: "default",
        processor_id: "sub_#{SecureRandom.hex(4)}",
        processor_plan: "price_hft_monthly",
        status: "active",
        quantity: 1,
        current_period_start: Time.current,
        current_period_end: 1.month.from_now,
        type: "Pay::Stripe::Subscription"
      )
    end.to have_enqueued_job(Licenses::SyncSubscriptionJob)
  end

  it "enqueues another sync when subscription status changes" do
    customer = user.pay_customers.create!(
      processor: "stripe",
      processor_id: "cus_#{SecureRandom.hex(4)}",
      default: true
    )
    subscription = customer.subscriptions.create!(
      name: "default",
      processor_id: "sub_#{SecureRandom.hex(4)}",
      processor_plan: "price_pandora_monthly",
      status: "active",
      quantity: 1,
      current_period_start: Time.current,
      current_period_end: 1.month.from_now
    )
    clear_enqueued_jobs

    expect do
      subscription.update!(status: "canceled", ends_at: Time.current)
    end.to have_enqueued_job(Licenses::SyncSubscriptionJob).with(subscription.id)
  end

  it "enqueues a user license reissue when the subscription period renews" do
    customer = user.pay_customers.create!(
      processor: "stripe",
      processor_id: "cus_#{SecureRandom.hex(4)}",
      default: true
    )
    subscription = customer.subscriptions.create!(
      name: "default",
      processor_id: "sub_#{SecureRandom.hex(4)}",
      processor_plan: "price_pandora_monthly",
      status: "active",
      quantity: 1,
      current_period_start: Time.current,
      current_period_end: 1.month.from_now
    )
    clear_enqueued_jobs

    expect do
      subscription.update!(
        current_period_start: subscription.current_period_end,
        current_period_end: subscription.current_period_end + 1.month
      )
    end.to have_enqueued_job(Licenses::SyncSubscriptionJob).with(subscription.id)
  end

  it "enqueues the same Discord convergence job after subscription changes" do
    connection = create(:discord_connection, :connected, user: user)
    allow(Discord).to receive(:enabled?).and_return(true)
    customer = user.pay_customers.create!(
      processor: "stripe",
      processor_id: "cus_#{SecureRandom.hex(4)}",
      default: true
    )

    expect do
      customer.subscriptions.create!(
        name: "default",
        processor_id: "sub_#{SecureRandom.hex(4)}",
        processor_plan: "price_pandora_monthly",
        status: "active",
        quantity: 1,
        current_period_start: Time.current,
        current_period_end: 1.month.from_now
      )
    end.to have_enqueued_job(Discord::SyncVipRoleJob).with(connection.id)
  end

  it "recomputes Discord access after failed, recovered, and deleted subscription callbacks" do
    connection = create(:discord_connection, :connected, user: user)
    allow(Discord).to receive(:enabled?).and_return(true)
    customer = user.pay_customers.create!(
      processor: "stripe",
      processor_id: "cus_#{SecureRandom.hex(4)}",
      default: true
    )
    subscription = customer.subscriptions.create!(
      name: "default",
      processor_id: "sub_#{SecureRandom.hex(4)}",
      processor_plan: "price_pandora_monthly",
      status: "active",
      quantity: 1,
      current_period_start: Time.current,
      current_period_end: 1.month.from_now
    )
    clear_enqueued_jobs

    expect do
      subscription.update!(status: "past_due")
    end.to have_enqueued_job(Discord::SyncVipRoleJob).with(connection.id)

    clear_enqueued_jobs
    expect do
      subscription.update!(status: "active")
    end.to have_enqueued_job(Discord::SyncVipRoleJob).with(connection.id)

    clear_enqueued_jobs
    expect do
      subscription.destroy!
    end.to have_enqueued_job(Discord::SyncVipRoleJob).with(connection.id)
  end
end
