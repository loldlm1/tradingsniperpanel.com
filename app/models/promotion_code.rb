class PromotionCode < ApplicationRecord
  CODE_FORMAT = /\A[A-Z0-9][A-Z0-9_-]*\z/.freeze

  scope :kept, -> { where(archived_at: nil) }
  scope :available, -> {
    kept.where("expires_at IS NULL OR expires_at > ?", Time.current)
  }
  scope :active, -> { available.where(active: true) }
  scope :ordered, -> { order(active: :desc, updated_at: :desc, id: :desc) }

  before_validation :normalize_code

  validates :code,
            presence: true,
            format: { with: CODE_FORMAT },
            uniqueness: {
              case_sensitive: false,
              conditions: -> { where(archived_at: nil) }
            }
  validates :percent_off, presence: true, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 100 }
  validates :title_en, :title_es, :body_en, :body_es, :cta_label_en, :cta_label_es, presence: true
  validates :max_redemptions, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true

  validate :expires_at_in_future
  validate :single_active_record
  validate :active_record_cannot_be_archived

  def self.current_active
    active.first
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[
      active
      archived_at
      code
      created_at
      cta_label_en
      cta_label_es
      expires_at
      id
      max_redemptions
      percent_off
      stripe_coupon_id
      stripe_promotion_code_id
      title_en
      title_es
      updated_at
    ]
  end

  def archived?
    archived_at.present?
  end

  def expired?
    expires_at.present? && expires_at <= Time.current
  end

  def active_for_checkout?
    active? && !archived? && !expired? && stripe_promotion_code_id.present?
  end

  def localized_title(locale = I18n.locale)
    localized_value(:title, locale)
  end

  def localized_body(locale = I18n.locale)
    localized_value(:body, locale)
  end

  def localized_cta_label(locale = I18n.locale)
    localized_value(:cta_label, locale)
  end

  def archive!
    update!(active: false, archived_at: Time.current)
  end

  def restore!
    update!(archived_at: nil)
  end

  private

  def normalize_code
    self.code = code.to_s.strip.upcase
  end

  def localized_value(prefix, locale)
    language = locale.to_s.start_with?("es") ? "es" : "en"
    public_send("#{prefix}_#{language}")
  end

  def single_active_record
    return unless active?
    return if archived?

    existing = self.class.kept.where(active: true).where.not(id: id)
    errors.add(:active, :taken) if existing.exists?
  end

  def active_record_cannot_be_archived
    return unless active? && archived?

    errors.add(:archived_at, :present)
  end

  def expires_at_in_future
    return if expires_at.blank?
    return if expires_at > Time.current

    errors.add(:expires_at, "must be in the future")
  end
end
