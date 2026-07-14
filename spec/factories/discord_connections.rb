FactoryBot.define do
  factory :discord_connection do
    association :user
    vip_role_state { "unknown" }
    sync_status { "idle" }

    trait :connected do
      sequence(:discord_user_id) { |n| (1_000_000_000_000_000_000 + n).to_s }
      discord_username { "trader" }
      discord_global_name { "Pandora Trader" }
      linked_at { Time.current }
    end
  end
end
