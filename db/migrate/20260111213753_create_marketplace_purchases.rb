class CreateMarketplacePurchases < ActiveRecord::Migration[7.1]
  def change
    create_table :marketplace_purchases do |t|
      t.references :user, null: false, foreign_key: true
      t.references :billing_plan, null: false, foreign_key: true
      t.references :pay_charge, foreign_key: { to_table: :pay_charges }
      t.datetime :purchased_at, null: false

      t.timestamps
    end

    add_index :marketplace_purchases, [:user_id, :billing_plan_id], unique: true
  end
end
