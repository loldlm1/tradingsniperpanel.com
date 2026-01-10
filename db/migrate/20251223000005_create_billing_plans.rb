class CreateBillingPlans < ActiveRecord::Migration[7.0]
  def change
    create_table :billing_plans do |t|
      t.string :key, null: false
      t.string :name, null: false
      t.text :description
      t.string :kind, null: false
      t.string :tier
      t.string :interval
      t.integer :interval_count, default: 1
      t.integer :amount_cents, null: false
      t.string :currency, null: false, default: "usd"
      t.string :stripe_product_id
      t.string :stripe_price_id
      t.boolean :active, null: false, default: true
      t.integer :sort_order, null: false, default: 0
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end

    add_index :billing_plans, :key, unique: true
    add_index :billing_plans, :name, unique: true
    add_index :billing_plans, :tier
    add_index :billing_plans, :kind
    add_index :billing_plans, :active
    add_index :billing_plans, :stripe_product_id
    add_index :billing_plans, :stripe_price_id, unique: true
  end
end
