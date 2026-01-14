class CourseLesson < ApplicationRecord
  belongs_to :course_module
  has_many :course_lesson_progresses, dependent: :destroy

  delegate :course, to: :course_module

  scope :ordered, -> { order(:position) }

  validates :title_en, :title_es, presence: true
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :duration_seconds, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def title_for(locale)
    localized_value(:title, locale)
  end

  def summary_for(locale)
    localized_value(:summary, locale)
  end

  def body_markdown_for(locale)
    localized_value(:body_markdown, locale)
  end

  private

  def localized_value(prefix, locale)
    key = "#{prefix}_#{locale}"
    value = respond_to?(key) ? public_send(key) : nil
    fallback_key = "#{prefix}_en"
    value.presence || public_send(fallback_key)
  end
end
