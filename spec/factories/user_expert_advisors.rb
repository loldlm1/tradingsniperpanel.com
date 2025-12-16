FactoryBot.define do
  factory :user_expert_advisor do
    association :user
    association :expert_advisor
    subscription_tier { "basic" }
    pay_subscription_id { "sub_123" }

    trait :expired do
      expires_at { 1.day.ago }
    end

    trait :deleted do
      deleted_at { Time.current }
    end
  end
end
