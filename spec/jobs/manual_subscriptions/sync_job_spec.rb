require "rails_helper"

RSpec.describe ManualSubscriptions::SyncJob, type: :job do
  include ActiveJob::TestHelper

  before do
    clear_enqueued_jobs
  end

  after do
    clear_enqueued_jobs
  end

  it "delegates to the race-safe manual subscription sync" do
    sync = instance_double(Licenses::ManualSubscriptionSync, call: true)
    allow(Licenses::ManualSubscriptionSync).to receive(:new)
      .with(manual_subscription_id: 123)
      .and_return(sync)

    described_class.perform_now(123)

    expect(sync).to have_received(:call)
  end

  it "enqueues Discord convergence for the connected user after license sync" do
    manual_subscription = create(:manual_subscription)
    connection = create(:discord_connection, :connected, user: manual_subscription.user)
    sync = instance_double(Licenses::ManualSubscriptionSync, call: true)
    allow(Licenses::ManualSubscriptionSync).to receive(:new)
      .with(manual_subscription_id: manual_subscription.id)
      .and_return(sync)
    allow(Discord).to receive(:enabled?).and_return(true)

    expect do
      described_class.perform_now(manual_subscription.id)
    end.to have_enqueued_job(Discord::SyncVipRoleJob).with(connection.id)
  end

  it "schedules future grants at their start boundary" do
    now = Time.current
    subscription = build(
      :manual_subscription,
      starts_at: now + 2.days,
      ends_at: now + 32.days,
      status: "active"
    )

    expect do
      subscription.save!
    end.to have_enqueued_job(described_class).with(subscription.id)
  end
end
