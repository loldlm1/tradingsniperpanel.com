class CreatePartnerProgram < ActiveRecord::Migration[8.0]
  def change
    create_table :partner_profiles do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.integer :discount_percent
      t.integer :payout_mode, null: false, default: 0
      t.datetime :started_at
      t.string :stripe_coupon_id
      t.boolean :active, null: false, default: true
      t.timestamps
    end

    create_table :partner_memberships do |t|
      t.references :partner_profile, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :referral, foreign_key: { to_table: :refer_referrals }
      t.integer :depth, null: false, default: 0
      t.datetime :started_at, null: false
      t.datetime :ended_at
      t.timestamps
    end
    add_index :partner_memberships, [:user_id, :ended_at], unique: true, where: "ended_at IS NULL"

    create_table :partner_payout_requests do |t|
      t.references :partner_profile, null: false, foreign_key: true
      t.integer :status, null: false, default: 0
      t.integer :total_cents, null: false, default: 0
      t.datetime :requested_at
      t.datetime :paid_at
      t.text :note
      t.string :payment_reference
      t.timestamps
    end

    create_table :partner_commissions do |t|
      t.references :partner_profile, null: false, foreign_key: true
      t.references :partner_membership, null: false, foreign_key: true
      t.references :referred_user, null: false, foreign_key: { to_table: :users }
      t.references :referral, foreign_key: { to_table: :refer_referrals }
      t.references :pay_charge, foreign_key: { to_table: :pay_charges }
      t.references :pay_subscription, foreign_key: { to_table: :pay_subscriptions }
      t.references :payout_request, foreign_key: { to_table: :partner_payout_requests }
      t.integer :commission_kind, null: false, default: 0
      t.integer :amount_cents, null: false, default: 0
      t.string :currency, null: false, default: "usd"
      t.integer :percent_applied
      t.integer :status, null: false, default: 0
      t.datetime :occurred_at, null: false
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end

    add_index :partner_commissions, [:partner_profile_id, :pay_charge_id], unique: true
    add_index :partner_commissions, :status
    add_index :partner_commissions, :commission_kind
  end
end
