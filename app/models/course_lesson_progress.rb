class CourseLessonProgress < ApplicationRecord
  belongs_to :user
  belongs_to :course_lesson

  enum :status, { started: "started", completed: "completed" }

  validates :course_lesson_id, uniqueness: { scope: :user_id }
  validates :progress_seconds, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
