FactoryBot.define do
  factory :license_online_session do
    association :user
    association :expert_advisor
    sequence(:company) { |n| "broker#{n}" }
    sequence(:account_number) { |n| 100_000 + n }
    account_type { "real" }
    entitlement_source { "subscription" }
    last_seen_at { Time.current }
  end
end
