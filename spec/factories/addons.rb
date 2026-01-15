FactoryBot.define do
  factory :addon do
    sequence(:key) { |n| "addon_#{n}" }
    association :billing_plan, factory: [:billing_plan, :one_time]
    association :addonable, factory: :expert_advisor
  end
end
