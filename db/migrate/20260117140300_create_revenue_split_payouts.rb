class CreateRevenueSplitPayouts < ActiveRecord::Migration[7.1]
  def change
    create_table :revenue_split_payouts do |t|
      t.string :period_key, null: false
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      t.integer :net_cents, null: false
      t.integer :us_cents, null: false
      t.integer :client_cents, null: false
      t.integer :status, null: false, default: 0
      t.datetime :paid_at
      t.references :paid_by_admin, foreign_key: { to_table: :users }
      t.text :notes

      t.timestamps
    end

    add_index :revenue_split_payouts, [:period_key, :starts_at, :ends_at], unique: true, name: "index_revenue_split_payouts_on_period"
  end
end
