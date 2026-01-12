FactoryBot.define do
  factory :marketplace_purchase do
    association :user
    association :billing_plan, factory: [:billing_plan, :one_time]
    purchased_at { Time.current }
  end
end
