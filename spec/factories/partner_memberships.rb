FactoryBot.define do
  factory :partner_membership do
    association :partner_profile
    association :user
    depth { 1 }
    started_at { Time.current }
  end
end
