FactoryBot.define do
  factory :course_lesson_progress do
    association :user
    association :course_lesson
    status { "started" }
    progress_seconds { 0 }
  end
end
