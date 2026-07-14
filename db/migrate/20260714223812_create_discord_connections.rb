class CreateDiscordConnections < ActiveRecord::Migration[8.0]
  def change
    create_table :discord_connections do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.string :discord_user_id
      t.string :discord_username
      t.string :discord_global_name
      t.datetime :linked_at
      t.datetime :disconnect_requested_at
      t.datetime :disconnected_at
      t.boolean :membership_pending
      t.string :vip_role_state, null: false, default: "unknown"
      t.string :sync_status, null: false, default: "idle"
      t.datetime :sync_started_at
      t.datetime :last_synced_at
      t.string :last_error_code
      t.datetime :last_error_at

      t.timestamps
    end

    add_index :discord_connections,
              :discord_user_id,
              unique: true,
              where: "discord_user_id IS NOT NULL"
    add_check_constraint :discord_connections,
                         "vip_role_state IN ('unknown', 'pending', 'granted', 'removed')",
                         name: "discord_connections_vip_role_state_check"
    add_check_constraint :discord_connections,
                         "sync_status IN ('idle', 'queued', 'syncing', 'failed')",
                         name: "discord_connections_sync_status_check"
    add_check_constraint :discord_connections,
                         "(discord_user_id IS NULL AND linked_at IS NULL) OR " \
                           "(discord_user_id IS NOT NULL AND linked_at IS NOT NULL)",
                         name: "discord_connections_identity_coherence_check"
  end
end
