class UpdateBrokerAccountDailyResultsForMagicLanes < ActiveRecord::Migration[8.0]
  def change
    remove_index :broker_account_daily_results,
                 name: "index_broker_account_daily_results_on_account_and_utc_day"

    add_reference :broker_account_daily_results,
                  :expert_advisor,
                  null: true,
                  foreign_key: true

    add_column :broker_account_daily_results, :magic_number, :bigint

    add_check_constraint :broker_account_daily_results,
                         "magic_number IS NULL OR magic_number > 0",
                         name: "broker_account_daily_results_magic_positive_check"

    add_index :broker_account_daily_results,
              "broker_account_id, expert_advisor_id, magic_number, ((to_timestamp(result_timestamp) AT TIME ZONE 'UTC')::date)",
              unique: true,
              where: "expert_advisor_id IS NOT NULL AND magic_number IS NOT NULL",
              name: "index_broker_daily_results_on_lane_magic_utc_day"

    add_index :broker_account_daily_results,
              [:expert_advisor_id, :magic_number, :result_timestamp],
              name: "index_broker_daily_results_on_ea_magic_and_timestamp"
  end
end
