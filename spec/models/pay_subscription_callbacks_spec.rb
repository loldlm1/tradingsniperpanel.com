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
end
