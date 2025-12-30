FactoryBot.define do
  factory :expert_advisor do
    sequence(:name) { |n| "Expert Advisor #{n}" }
    description { "Sample expert advisor description" }
    ea_type { :ea_robot }
    tier_rank { 0 }
    doc_guide_en { "# Sample Guide\n\nThis is a preview paragraph." }
    doc_guide_es { "# Guía de ejemplo\n\nEste es un párrafo de vista previa." }
    allowed_subscription_tiers { %w[basic pro] }
  end
end
