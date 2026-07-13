FactoryBot.define do
  factory :billing_plan_price do
    association :billing_plan
    sequence(:stripe_price_id) { |n| "price_history_#{n}" }
    amount_cents { billing_plan.amount_cents }
    currency { billing_plan.currency }
    interval { billing_plan.subscription? ? billing_plan.interval : nil }
    interval_count { billing_plan.subscription? ? billing_plan.interval_count : nil }
    active { true }
    current { false }
    retired_at { nil }
    metadata { { "billing_plan_key" => billing_plan.key } }
  end
end
