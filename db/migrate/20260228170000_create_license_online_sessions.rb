class CreateLicenseOnlineSessions < ActiveRecord::Migration[8.0]
  def change
    create_table :license_online_sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :expert_advisor, null: false, foreign_key: true
      t.string :company, null: false
      t.bigint :account_number, null: false
      t.string :account_type, null: false
      t.string :entitlement_source, null: false
      t.datetime :last_seen_at, null: false

      t.timestamps
    end

    add_index :license_online_sessions,
              [:user_id, :expert_advisor_id, :company, :account_number, :account_type],
              unique: true,
              name: "index_license_online_sessions_on_identity"

    add_index :license_online_sessions,
              [:user_id, :entitlement_source, :last_seen_at],
              name: "index_license_online_sessions_on_user_source_seen_at"

    add_index :license_online_sessions,
              [:user_id, :expert_advisor_id, :entitlement_source, :last_seen_at],
              name: "index_license_online_sessions_on_user_ea_source_seen_at"

    add_check_constraint :license_online_sessions,
                         "account_type IN ('real', 'demo')",
                         name: "license_online_sessions_account_type_check"

    add_check_constraint :license_online_sessions,
                         "entitlement_source IN ('subscription', 'one_time')",
                         name: "license_online_sessions_entitlement_source_check"
  end
end
