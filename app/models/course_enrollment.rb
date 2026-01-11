class CourseEnrollment < ApplicationRecord
  belongs_to :user
  belongs_to :course
  belongs_to :last_lesson, class_name: "CourseLesson", optional: true

  validates :course_id, uniqueness: { scope: :user_id }
  validates :progress_percent, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
end
