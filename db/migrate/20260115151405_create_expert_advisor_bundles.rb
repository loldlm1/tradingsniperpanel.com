class CreateExpertAdvisorBundles < ActiveRecord::Migration[7.1]
  def change
    create_table :expert_advisor_bundles do |t|
      t.references :expert_advisor, null: false, foreign_key: true
      t.string :bundle_key, null: false
      t.string :required_addon_keys, null: false, default: ""
      t.boolean :active, null: false, default: true
      t.integer :sort_order, null: false, default: 0
      t.timestamps
    end

    add_index :expert_advisor_bundles, [:expert_advisor_id, :bundle_key], unique: true, name: "index_ea_bundles_on_ea_and_key"
  end
end
