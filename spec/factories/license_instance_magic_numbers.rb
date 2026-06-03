FactoryBot.define do
  sequence(:license_instance_magic_account_number) { |n| 650_000 + n }

  factory :license_instance_magic_number do
    association :license
    broker_account do
      association(
        :broker_account,
        license: license,
        company: "InstanceBroker",
        account_number: generate(:license_instance_magic_account_number)
      )
    end
    expert_advisor { license.expert_advisor }
    source { ENV.fetch("EA_LICENSE_SOURCE_ID", "trading_sniper_floor") }
    email { license.user.email }
    sequence(:instance_id) { |n| "instance_#{n}" }
    sequence(:magic_number) { |n| 700_000_000 + n }
    first_seen_at { Time.current }
    last_seen_at { Time.current }
  end
end
