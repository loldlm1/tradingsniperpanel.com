class SimplifyManualSubscriptions < ActiveRecord::Migration[8.0]
  def up
    add_column :manual_subscriptions, :granted_days, :integer
    add_column :manual_subscriptions, :payment_status, :string, default: "paid", null: false
    add_column :manual_subscriptions, :superseded_at, :datetime
    add_reference :manual_subscriptions,
                  :superseded_by_pay_subscription,
                  foreign_key: { to_table: :pay_subscriptions }

    change_column_default :manual_subscriptions, :amount_cents, from: nil, to: 0
    change_column_null :manual_subscriptions, :paid_at, true

    execute <<~SQL.squish
      UPDATE manual_subscriptions
      SET granted_days = GREATEST(
        1,
        CEIL(EXTRACT(EPOCH FROM (ends_at - starts_at)) / 86400.0)::integer
      ),
      payment_status = 'paid'
    SQL

    add_check_constraint :manual_subscriptions,
                         "amount_cents >= 0",
                         name: "manual_subscriptions_amount_non_negative_check"
    add_check_constraint :manual_subscriptions,
                         "granted_days IS NULL OR granted_days > 0",
                         name: "manual_subscriptions_granted_days_positive_check"
    add_check_constraint :manual_subscriptions,
                         "ends_at > starts_at",
                         name: "manual_subscriptions_period_order_check"
    add_check_constraint :manual_subscriptions,
                         "status IN ('active', 'expired', 'cancelled', 'superseded')",
                         name: "manual_subscriptions_status_check"
    add_check_constraint :manual_subscriptions,
                         "payment_status IN ('complimentary', 'pending', 'paid')",
                         name: "manual_subscriptions_payment_status_check"
    add_check_constraint :manual_subscriptions,
                         payment_coherence_sql,
                         name: "manual_subscriptions_payment_coherence_check"
    add_check_constraint :manual_subscriptions,
                         supersession_coherence_sql,
                         name: "manual_subscriptions_supersession_coherence_check"

    add_index :manual_subscriptions, :payment_status
    add_index :manual_subscriptions, :superseded_at
  end

  def down
    remove_index :manual_subscriptions, :superseded_at
    remove_index :manual_subscriptions, :payment_status

    remove_check_constraint :manual_subscriptions, name: "manual_subscriptions_supersession_coherence_check"
    remove_check_constraint :manual_subscriptions, name: "manual_subscriptions_payment_coherence_check"
    remove_check_constraint :manual_subscriptions, name: "manual_subscriptions_payment_status_check"
    remove_check_constraint :manual_subscriptions, name: "manual_subscriptions_status_check"
    remove_check_constraint :manual_subscriptions, name: "manual_subscriptions_period_order_check"
    remove_check_constraint :manual_subscriptions, name: "manual_subscriptions_granted_days_positive_check"
    remove_check_constraint :manual_subscriptions, name: "manual_subscriptions_amount_non_negative_check"

    change_column_null :manual_subscriptions, :paid_at, false
    change_column_default :manual_subscriptions, :amount_cents, from: 0, to: nil

    remove_reference :manual_subscriptions,
                     :superseded_by_pay_subscription,
                     foreign_key: { to_table: :pay_subscriptions }
    remove_column :manual_subscriptions, :superseded_at
    remove_column :manual_subscriptions, :payment_status
    remove_column :manual_subscriptions, :granted_days
  end

  private

  def payment_coherence_sql
    <<~SQL.squish
      (payment_status = 'paid' AND paid_at IS NOT NULL AND amount_cents > 0)
      OR (payment_status = 'pending' AND paid_at IS NULL)
      OR (payment_status = 'complimentary' AND paid_at IS NULL AND amount_cents = 0)
    SQL
  end

  def supersession_coherence_sql
    <<~SQL.squish
      (status = 'superseded' AND superseded_at IS NOT NULL)
      OR (
        status <> 'superseded'
        AND superseded_at IS NULL
        AND superseded_by_pay_subscription_id IS NULL
      )
    SQL
  end
end
