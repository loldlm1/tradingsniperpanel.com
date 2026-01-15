FactoryBot.define do
  factory :expert_advisor_bundle do
    association :expert_advisor
    bundle_key { "base" }
    required_addon_keys { "" }
    active { true }
    sort_order { 0 }
  end
end
