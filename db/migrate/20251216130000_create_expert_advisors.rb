class CreateExpertAdvisors < ActiveRecord::Migration[8.0]
  def change
    create_table :expert_advisors do |t|
      t.string :name, null: false
      t.text :description
      t.integer :ea_type, null: false, default: 0
      t.jsonb :documents, null: false, default: {}
      t.jsonb :allowed_subscription_tiers, null: false, default: []
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :expert_advisors, :ea_type
    add_index :expert_advisors, :deleted_at
  end
end
