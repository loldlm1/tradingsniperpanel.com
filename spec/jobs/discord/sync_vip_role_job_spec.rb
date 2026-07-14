require "rails_helper"

RSpec.describe Discord::SyncVipRoleJob, type: :job do
  include ActiveJob::TestHelper

  let(:connection) { create(:discord_connection, :connected) }

  before do
    clear_enqueued_jobs
    allow(Discord).to receive(:enabled?).and_return(true)
  end

  after do
    clear_enqueued_jobs
  end

  it "enqueues only the connection ID and marks the row queued" do
    expect do
      described_class.enqueue(connection.id)
    end.to have_enqueued_job(described_class).with(connection.id)

    job = enqueued_jobs.last
    expect(job.fetch(:args)).to eq([ connection.id ])
    expect(connection.reload.sync_status).to eq("queued")
  end

  it "does not enqueue when disabled or disconnected" do
    allow(Discord).to receive(:enabled?).and_return(false)
    expect(described_class.enqueue(connection.id)).to be(false)

    allow(Discord).to receive(:enabled?).and_return(true)
    connection.update!(discord_user_id: nil, linked_at: nil)
    expect(described_class.enqueue(connection.id)).to be(false)
    expect(enqueued_jobs).to be_empty
  end

  it "schedules a rate-limited retry without sleeping" do
    result = Discord::SyncVipRole::Result.new(outcome: :rate_limited, retry_after: 2.5, follow_up: false)
    sync = instance_double(Discord::SyncVipRole, call: result)
    allow(Discord::SyncVipRole).to receive(:new).with(connection_id: connection.id).and_return(sync)

    expect do
      described_class.perform_now(connection.id)
    end.to have_enqueued_job(described_class).with(connection.id)

    expect(connection.reload.sync_status).to eq("queued")
  end

  it "uses Active Job retry behavior for transient failures" do
    result = Discord::SyncVipRole::Result.new(outcome: :retryable_failure, retry_after: nil, follow_up: false)
    sync = instance_double(Discord::SyncVipRole, call: result)
    allow(Discord::SyncVipRole).to receive(:new).with(connection_id: connection.id).and_return(sync)

    expect do
      described_class.perform_now(connection.id)
    end.to have_enqueued_job(described_class).with(connection.id)
  end

  it "enqueues a follow-up convergence pass" do
    result = Discord::SyncVipRole::Result.new(outcome: :granted, retry_after: nil, follow_up: true)
    sync = instance_double(Discord::SyncVipRole, call: result)
    allow(Discord::SyncVipRole).to receive(:new).with(connection_id: connection.id).and_return(sync)

    expect do
      described_class.perform_now(connection.id)
    end.to have_enqueued_job(described_class).with(connection.id)
  end
end
