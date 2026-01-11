FactoryBot.define do
  factory :course_enrollment do
    association :user
    association :course
    progress_percent { 0 }
  end
end
