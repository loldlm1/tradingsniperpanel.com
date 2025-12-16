class CreateUserExpertAdvisors < ActiveRecord::Migration[8.0]
  def change
    create_table :user_expert_advisors do |t|
      t.references :user, null: false, foreign_key: true
      t.references :expert_advisor, null: false, foreign_key: true
      t.string :subscription_tier
      t.string :pay_subscription_id
      t.datetime :expires_at
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :user_expert_advisors, [:user_id, :expert_advisor_id, :deleted_at], unique: true, name: "index_user_eas_unique_active"
  end
end
