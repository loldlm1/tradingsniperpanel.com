FactoryBot.define do
  factory :billing_plan do
    sequence(:tier) { |n| "tier#{n}" }
    interval { "month" }
    interval_count { 1 }
    kind { "subscription" }
    amount_cents { 1000 }
    currency { "usd" }
    active { true }
    sort_order { 0 }
    metadata { {} }

    sequence(:stripe_price_id) { |n| "price_#{n}" }
    sequence(:stripe_product_id) { |n| "prod_#{n}" }

    key { "#{tier}_#{Billing::IntervalLabeler.interval_key(interval: interval, interval_count: interval_count)}" }
    name { "#{tier.to_s.humanize} #{Billing::IntervalLabeler.label(interval: interval, interval_count: interval_count)}" }

    trait :annual do
      interval { "year" }
      interval_count { 1 }
      key { "#{tier}_annual" }
    end

    trait :one_time do
      kind { "one_time" }
      tier { nil }
      interval { nil }
      interval_count { nil }
      sequence(:key) { |n| "one_time_#{n}" }
      sequence(:name) { |n| "One-Time #{n}" }
    end
  end
end
