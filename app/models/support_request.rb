class SupportRequest < ApplicationRecord
  MAX_SCREENSHOTS = 3
  MAX_SCREENSHOT_SIZE = 5.megabytes
  ALLOWED_SCREENSHOT_TYPES = %w[image/png image/jpeg image/webp image/gif].freeze

  belongs_to :user
  has_many_attached :screenshots

  validates :message, presence: true, length: { maximum: 5_000 }
  validates :locale, presence: true
  validate :screenshots_count_within_limit
  validate :screenshots_are_supported_images
  validate :screenshots_within_size_limit

  def purge_uploaded_screenshots
    screenshots.blobs.each(&:purge)
  end

  private

  def screenshots_count_within_limit
    return if screenshots.attachments.size <= MAX_SCREENSHOTS

    errors.add(:screenshots, I18n.t("dashboard.support_screenshots_limit_error", count: MAX_SCREENSHOTS))
  end

  def screenshots_are_supported_images
    screenshots.each do |screenshot|
      next if ALLOWED_SCREENSHOT_TYPES.include?(screenshot.blob.content_type)

      errors.add(:screenshots, I18n.t("dashboard.support_screenshots_type_error"))
    end
  end

  def screenshots_within_size_limit
    screenshots.each do |screenshot|
      next if screenshot.blob.byte_size <= MAX_SCREENSHOT_SIZE

      errors.add(:screenshots, I18n.t("dashboard.support_screenshots_size_error", size: "5 MB"))
    end
  end
end
