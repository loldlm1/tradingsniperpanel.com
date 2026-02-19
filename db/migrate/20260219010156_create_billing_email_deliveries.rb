class CreateBillingEmailDeliveries < ActiveRecord::Migration[8.0]
  def change
    create_table :billing_email_deliveries do |t|
      t.string :event_key, null: false
      t.string :event_type, null: false
      t.string :invoice_id
      t.references :user, foreign_key: true
      t.references :pay_charge, foreign_key: { to_table: :pay_charges }
      t.references :pay_subscription, foreign_key: { to_table: :pay_subscriptions }
      t.jsonb :metadata, null: false, default: {}
      t.datetime :delivered_at, null: false

      t.timestamps
    end

    add_index :billing_email_deliveries, :event_key, unique: true
    add_index :billing_email_deliveries, %i[event_type invoice_id], name: "index_billing_email_deliveries_on_type_and_invoice"
  end
end
