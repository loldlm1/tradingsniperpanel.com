require "rails_helper"

RSpec.describe DiscordConnection, type: :model do
  it "allows one durable connection row per user" do
    connection = create(:discord_connection)
    duplicate = build(:discord_connection, user: connection.user)

    expect(duplicate).not_to be_valid
    expect do
      duplicate.save!(validate: false)
    end.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "prevents one Discord identity from belonging to multiple users" do
    connection = create(:discord_connection, :connected)
    duplicate = build(:discord_connection, :connected, discord_user_id: connection.discord_user_id)

    expect(duplicate).not_to be_valid
    expect do
      duplicate.save!(validate: false)
    end.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "can reconnect the same Rails user to a different Discord identity after clearing the old identity" do
    connection = create(:discord_connection, :connected)

    connection.update!(
      discord_user_id: nil,
      discord_username: nil,
      discord_global_name: nil,
      linked_at: nil,
      disconnected_at: Time.current,
      vip_role_state: "removed"
    )
    connection.update!(
      discord_user_id: "2000000000000000000",
      discord_username: "new-trader",
      linked_at: Time.current,
      disconnected_at: nil
    )

    expect(connection.reload).to be_connected
    expect(connection.discord_user_id).to eq("2000000000000000000")
  end

  it "enforces status values at the model and database levels" do
    connection = create(:discord_connection)

    connection.sync_status = "broken"
    expect(connection).not_to be_valid
    expect do
      connection.update_column(:sync_status, "broken")
    end.to raise_error(ActiveRecord::StatementInvalid)
  end

  it "requires Discord identity and linked timestamp to be present together" do
    connection = build(:discord_connection, discord_user_id: "3000000000000000000", linked_at: nil)

    expect(connection).not_to be_valid
    expect do
      described_class.insert_all!([
        {
          user_id: create(:user).id,
          discord_user_id: "3000000000000000001",
          linked_at: nil,
          vip_role_state: "unknown",
          sync_status: "idle",
          created_at: Time.current,
          updated_at: Time.current
        }
      ])
    end.to raise_error(ActiveRecord::StatementInvalid)
  end

  it "provides connected, disconnect-pending, failed, and reconciliation scopes" do
    connected = create(:discord_connection, :connected)
    pending = create(:discord_connection, :connected, disconnect_requested_at: Time.current)
    failed = create(:discord_connection, sync_status: "failed")

    expect(described_class.connected).to contain_exactly(connected, pending)
    expect(described_class.disconnect_pending).to contain_exactly(pending)
    expect(described_class.failed).to contain_exactly(failed)
    expect(described_class.reconcilable).to contain_exactly(connected, pending)
  end

  it "does not persist OAuth or bot credentials" do
    expect(described_class.column_names).not_to include(
      "access_token",
      "refresh_token",
      "bot_token",
      "oauth_token"
    )
  end
end
