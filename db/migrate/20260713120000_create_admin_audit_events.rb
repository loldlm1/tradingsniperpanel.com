class CreateAdminAuditEvents < ActiveRecord::Migration[8.0]
  def up
    create_table :admin_audit_events do |t|
      t.references :actor, null: false, foreign_key: { to_table: :users }
      t.string :action, null: false
      t.references :target, polymorphic: true, index: false
      t.jsonb :metadata, null: false, default: {}
      t.string :request_id, null: false

      t.timestamps
    end

    add_index :admin_audit_events, :request_id, unique: true
    add_index :admin_audit_events, [ :action, :created_at ]
    add_index :admin_audit_events, [ :target_type, :target_id, :created_at ],
              name: "index_admin_audit_events_on_target_and_created_at"
    add_index :admin_audit_events, :created_at
    add_check_constraint :admin_audit_events,
                         "action IN ('manual_subscription.granted', " \
                         "'licenses.subscription_rotated', 'licenses.all_rotated')",
                         name: "admin_audit_events_action_check"
    add_check_constraint :admin_audit_events,
                         "jsonb_typeof(metadata) = 'object'",
                         name: "admin_audit_events_metadata_object_check"
    add_check_constraint :admin_audit_events,
                         "char_length(request_id) BETWEEN 1 AND 128",
                         name: "admin_audit_events_request_id_length_check"
    add_check_constraint :admin_audit_events,
                         "(action = 'licenses.all_rotated' AND target_type IS NULL AND target_id IS NULL) OR " \
                         "(action IN ('manual_subscription.granted', 'licenses.subscription_rotated') AND " \
                         "target_type = 'User' AND target_id IS NOT NULL)",
                         name: "admin_audit_events_target_action_check"
  end

  def down
    drop_table :admin_audit_events
  end
end
