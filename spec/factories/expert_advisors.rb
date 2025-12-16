FactoryBot.define do
  factory :expert_advisor do
    sequence(:name) { |n| "Expert Advisor #{n}" }
    description { "Sample expert advisor description" }
    ea_type { :ea_robot }
    documents { { guide: "http://example.com/guide" } }
    allowed_subscription_tiers { %w[basic pro] }
  end
end
