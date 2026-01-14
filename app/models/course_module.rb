class CourseModule < ApplicationRecord
  belongs_to :course
  has_many :course_lessons, dependent: :destroy

  scope :ordered, -> { order(:position) }

  validates :title_en, :title_es, presence: true
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def title_for(locale)
    localized_value(:title, locale)
  end

  def summary_for(locale)
    localized_value(:summary, locale)
  end

  private

  def localized_value(prefix, locale)
    key = "#{prefix}_#{locale}"
    value = respond_to?(key) ? public_send(key) : nil
    fallback_key = "#{prefix}_en"
    value.presence || public_send(fallback_key)
  end
end
