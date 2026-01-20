FactoryBot.define do
  factory :asset_plan_entitlement do
    association :billing_plan, factory: [:billing_plan, :one_time]
    association :marketplace_asset
  end
end
