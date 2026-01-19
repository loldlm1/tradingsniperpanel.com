FactoryBot.define do
  factory :manual_transaction do
    association :user
    association :billing_plan, factory: [:billing_plan, :one_time]
    amount_cents { 2500 }
    currency { "usd" }
    paid_at { Time.current }
    association :recorded_by_admin, factory: [:user, :admin]
  end
end
