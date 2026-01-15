class CreateAddons < ActiveRecord::Migration[7.1]
  def change
    create_table :addons do |t|
      t.string :key, null: false
      t.references :billing_plan, null: false, foreign_key: true, index: { unique: true }
      t.references :addonable, null: false, polymorphic: true
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end

    add_index :addons, :key, unique: true
    add_check_constraint :addons, "addonable_type IN ('ExpertAdvisor', 'Course')", name: "addons_addonable_type_check"
  end
end
