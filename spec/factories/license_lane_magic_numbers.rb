FactoryBot.define do
  factory :license_lane_magic_number do
    association :license
    source { ENV.fetch("EA_LICENSE_SOURCE_ID", "trading_sniper_floor") }
    email { license.user.email }
    sequence(:company) { |n| "broker#{n}" }
    sequence(:account_number) { |n| 200_000 + n }
    account_type { "real" }
    sequence(:magic_number) { |n| 900_000_000 + n }
  end
end
