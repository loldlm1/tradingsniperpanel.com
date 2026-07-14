require "rails_helper"

RSpec.describe Discord::RequestUnlink do
  include ActiveJob::TestHelper

  let(:user) { create(:user) }
  let!(:connection) { create(:discord_connection, :connected, user: user, vip_role_state: "granted") }

  before do
    clear_enqueued_jobs
    allow(Discord).to receive(:enabled?).and_return(true)
  end

  after do
    clear_enqueued_jobs
  end

  it "marks unlink pending and enqueues role removal by connection ID" do
    result = described_class.new(user: user).call

    expect(result.status).to eq(:pending)
    expect(connection.reload.disconnect_requested_at).to be_present
    expect(enqueued_jobs.last.fetch(:args)).to eq([ connection.id ])
  end

  it "is idempotent for repeated unlink requests" do
    described_class.new(user: user).call
    requested_at = connection.reload.disconnect_requested_at

    expect do
      described_class.new(user: user).call
    end.to have_enqueued_job(Discord::SyncVipRoleJob).with(connection.id)

    expect(connection.reload.disconnect_requested_at).to eq(requested_at)
  end

  it "clears identity only after Discord confirms role removal" do
    described_class.new(user: user).call
    client = instance_double(Discord::Client, remove_vip_role: true, add_vip_role: true)

    result = Discord::SyncVipRole.new(connection_id: connection.id, client: client).call

    expect(result.outcome).to eq(:removed)
    expect(client).to have_received(:remove_vip_role).with(user_id: connection.discord_user_id)
    expect(connection.reload).to have_attributes(
      discord_user_id: nil,
      discord_username: nil,
      discord_global_name: nil,
      linked_at: nil,
      disconnect_requested_at: nil,
      vip_role_state: "removed"
    )
    expect(connection.disconnected_at).to be_present
  end

  it "retains identity and a safe failed state when Discord refuses removal" do
    described_class.new(user: user).call
    client = instance_double(Discord::Client, add_vip_role: true)
    allow(client).to receive(:remove_vip_role).and_raise(
      Discord::ForbiddenError.new(code: :forbidden, status: 403)
    )

    result = Discord::SyncVipRole.new(connection_id: connection.id, client: client).call

    expect(result.outcome).to eq(:operational_failure)
    expect(connection.reload).to have_attributes(
      discord_user_id: connection.discord_user_id,
      sync_status: "failed",
      last_error_code: "forbidden"
    )
  end

  it "does not change state while the integration is disabled" do
    allow(Discord).to receive(:enabled?).and_return(false)

    result = described_class.new(user: user).call

    expect(result.status).to eq(:disabled)
    expect(connection.reload.disconnect_requested_at).to be_nil
    expect(enqueued_jobs).to be_empty
  end

  it "treats an already disconnected row as complete" do
    connection.update!(discord_user_id: nil, linked_at: nil, disconnected_at: Time.current)

    result = described_class.new(user: user).call

    expect(result.status).to eq(:already_disconnected)
    expect(enqueued_jobs).to be_empty
  end
end
