# frozen_string_literal: true

class CreateManualTransactions < ActiveRecord::Migration[8.0]
  def change
    create_table :manual_transactions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :billing_plan, null: false, foreign_key: true
      t.integer :amount_cents, null: false
      t.string :currency, null: false, default: "usd"
      t.datetime :paid_at, null: false
      t.string :payment_method
      t.string :reference
      t.text :notes
      t.references :recorded_by_admin, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :manual_transactions, [:user_id, :billing_plan_id], unique: true
    add_index :manual_transactions, :paid_at
  end
end
