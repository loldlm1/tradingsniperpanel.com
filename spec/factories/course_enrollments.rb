FactoryBot.define do
  factory :course_enrollment do
    association :user
    association :course
    progress_percent { 0 }

    trait :one_time do
      access_source { "one_time" }
      purchased_at { Time.current }
    end
  end
end
