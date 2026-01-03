FactoryBot.define do
  factory :broker_account_daily_result do
    association :broker_account
    result_timestamp { Time.utc(2025, 1, 15, 12, 0, 0).to_i }
    result_value { 10.25 }
  end
end
