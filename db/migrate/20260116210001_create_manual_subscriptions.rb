# frozen_string_literal: true

class CreateManualSubscriptions < ActiveRecord::Migration[8.0]
  def change
    create_table :manual_subscriptions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :billing_plan, null: false, foreign_key: true
      t.integer :amount_cents, null: false
      t.string :currency, null: false, default: "usd"
      t.datetime :paid_at, null: false
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      t.string :status, null: false, default: "active"
      t.string :payment_method
      t.string :reference
      t.text :notes
      t.references :recorded_by_admin, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :manual_subscriptions, [:user_id, :billing_plan_id]
    add_index :manual_subscriptions, :ends_at
    add_index :manual_subscriptions, :paid_at
  end
end
