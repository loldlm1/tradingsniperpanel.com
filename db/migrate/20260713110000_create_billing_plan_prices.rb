class CreateBillingPlanPrices < ActiveRecord::Migration[8.0]
  def up
    create_table :billing_plan_prices do |t|
      t.references :billing_plan, null: false, foreign_key: true
      t.string :stripe_price_id, null: false
      t.integer :amount_cents, null: false
      t.string :currency, null: false
      t.string :interval
      t.integer :interval_count
      t.boolean :active, default: true, null: false
      t.boolean :current, default: false, null: false
      t.datetime :retired_at
      t.jsonb :metadata, default: {}, null: false

      t.timestamps
    end

    add_index :billing_plan_prices, :stripe_price_id, unique: true
    add_index :billing_plan_prices, :active
    add_index :billing_plan_prices, :retired_at
    add_index :billing_plan_prices,
              :billing_plan_id,
              unique: true,
              where: '"current" = TRUE',
              name: "index_billing_plan_prices_on_current_plan"

    add_check_constraint :billing_plan_prices,
                         "amount_cents > 0",
                         name: "billing_plan_prices_amount_positive_check"
    add_check_constraint :billing_plan_prices,
                         recurrence_coherence_sql,
                         name: "billing_plan_prices_recurrence_coherence_check"
    add_check_constraint :billing_plan_prices,
                         current_coherence_sql,
                         name: "billing_plan_prices_current_coherence_check"

    execute <<~SQL.squish
      INSERT INTO billing_plan_prices (
        billing_plan_id,
        stripe_price_id,
        amount_cents,
        currency,
        interval,
        interval_count,
        active,
        "current",
        retired_at,
        metadata,
        created_at,
        updated_at
      )
      SELECT
        id,
        stripe_price_id,
        amount_cents,
        LOWER(currency),
        CASE WHEN kind = 'subscription' THEN interval ELSE NULL END,
        CASE WHEN kind = 'subscription' THEN interval_count ELSE NULL END,
        TRUE,
        TRUE,
        NULL,
        jsonb_build_object('billing_plan_key', key),
        created_at,
        CURRENT_TIMESTAMP
      FROM billing_plans
      WHERE stripe_price_id IS NOT NULL
    SQL
  end

  def down
    drop_table :billing_plan_prices
  end

  private

  def recurrence_coherence_sql
    <<~SQL.squish
      (interval IS NULL AND interval_count IS NULL)
      OR (
        interval IN ('day', 'week', 'month', 'year')
        AND interval_count > 0
      )
    SQL
  end

  def current_coherence_sql
    <<~SQL.squish
      NOT "current"
      OR (active = TRUE AND retired_at IS NULL)
    SQL
  end
end
