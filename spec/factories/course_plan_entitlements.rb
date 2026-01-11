FactoryBot.define do
  factory :course_plan_entitlement do
    association :course
    association :billing_plan
  end
end
