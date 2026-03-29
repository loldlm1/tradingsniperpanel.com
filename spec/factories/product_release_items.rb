FactoryBot.define do
  factory :product_release_item do
    association :product_release
    association :subject, factory: :marketplace_product
    product_kind { :addon }
    action_type { :added }
    title_en { "New Add-on" }
    title_es { "Nuevo Add-on" }
    position { 0 }

    trait :expert_advisor_update do
      association :subject, factory: :expert_advisor
      product_kind { :expert_advisor }
      action_type { :updated }
      title_en { "Expert Advisor Update" }
      title_es { "Actualizacion de Expert Advisor" }
    end

    trait :course_addition do
      association :subject, factory: :course
      product_kind { :course }
      action_type { :added }
      title_en { "New Course" }
      title_es { "Nuevo Curso" }
    end
  end
end
