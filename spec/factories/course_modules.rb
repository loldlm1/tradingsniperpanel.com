FactoryBot.define do
  factory :course_module do
    association :course
    position { 0 }
    sequence(:title_en) { |n| "Module #{n}" }
    sequence(:title_es) { |n| "Modulo #{n}" }
    summary_en { "Module summary." }
    summary_es { "Resumen del modulo." }
  end
end
