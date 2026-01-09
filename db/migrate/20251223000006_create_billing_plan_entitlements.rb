class CreateBillingPlanEntitlements < ActiveRecord::Migration[7.0]
  def change
    create_table :billing_plan_entitlements do |t|
      t.references :billing_plan, null: false, foreign_key: true
      t.references :expert_advisor, null: false, foreign_key: true
      t.timestamps
    end

    add_index :billing_plan_entitlements,
              [:billing_plan_id, :expert_advisor_id],
              unique: true,
              name: "index_billing_plan_entitlements_unique"
  end
end
