class CreateAssetPlanEntitlements < ActiveRecord::Migration[7.1]
  def change
    create_table :asset_plan_entitlements do |t|
      t.references :billing_plan, null: false, foreign_key: true
      t.references :marketplace_asset, null: false, foreign_key: true

      t.timestamps
    end

    add_index :asset_plan_entitlements, [:billing_plan_id, :marketplace_asset_id],
              unique: true,
              name: "index_asset_plan_entitlements_unique"
  end
end
