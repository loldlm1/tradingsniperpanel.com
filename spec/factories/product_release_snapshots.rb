FactoryBot.define do
  factory :product_release_snapshot do
    subject_type { "Course" }
    sequence(:subject_id) { |n| n }
    product_kind { :course }
    signature { "course-published:v1" }
    tracked_at { Time.current }
  end
end
