class CreateBrokerAccountDailyResults < ActiveRecord::Migration[8.0]
  def change
    create_table :broker_account_daily_results do |t|
      t.references :broker_account, null: false, foreign_key: true
      t.bigint :result_timestamp, null: false
      t.decimal :result_value, precision: 12, scale: 2, null: false

      t.timestamps
    end

    add_index :broker_account_daily_results, :result_timestamp
    add_index :broker_account_daily_results, [:broker_account_id, :result_timestamp],
              name: "index_broker_account_daily_results_on_account_and_timestamp"
    add_index :broker_account_daily_results,
              "broker_account_id, ((to_timestamp(result_timestamp) AT TIME ZONE 'UTC')::date)",
              unique: true,
              name: "index_broker_account_daily_results_on_account_and_utc_day"
  end
end
