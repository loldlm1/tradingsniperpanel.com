FactoryBot.define do
  factory :manual_subscription do
    association :user
    association :billing_plan
    amount_cents { 5000 }
    currency { "usd" }
    paid_at { Time.current }
    starts_at { 1.day.ago }
    ends_at { 29.days.from_now }
    status { "active" }
    association :recorded_by_admin, factory: [:user, :admin]
  end
end
