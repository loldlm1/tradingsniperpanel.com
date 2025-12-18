class CreateLicenses < ActiveRecord::Migration[8.0]
  def change
    create_table :licenses do |t|
      t.references :user, null: false, foreign_key: true
      t.references :expert_advisor, null: false, foreign_key: true
      t.string :status, null: false, default: "trial"
      t.string :plan_interval
      t.datetime :expires_at
      t.datetime :trial_ends_at
      t.string :encrypted_key, null: false
      t.string :source
      t.datetime :last_synced_at

      t.timestamps
    end

    add_index :licenses, [:user_id, :expert_advisor_id], unique: true
    add_index :licenses, :status
    add_index :licenses, :expires_at
    add_index :licenses, :trial_ends_at
  end
end
