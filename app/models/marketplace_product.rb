class MarketplaceProduct < ApplicationRecord
  has_one_attached :image

  belongs_to :billing_plan
  has_many :expert_advisors, through: :billing_plan
  has_many :courses, through: :billing_plan
  has_one :addon, through: :billing_plan

  enum :status, { draft: "draft", active: "active" }

  scope :ordered, -> { order(:sort_order, :title_en) }

  before_validation :normalize_slug, on: :create
  before_validation :assign_key, on: :create

  validate :key_matches_slug
  validate :billing_plan_is_one_time
  validate :billing_plan_has_stripe_ids
  validate :slug_immutable, on: :update
  validate :key_immutable, on: :update

  validates :slug, presence: true, uniqueness: true
  validates :key, presence: true, uniqueness: true
  validates :status, presence: true
  validates :title_en, :title_es, presence: true
  validates :sort_order, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def to_param
    slug
  end

  def title_for(locale)
    localized_value(:title, locale)
  end

  def summary_for(locale)
    localized_value(:summary, locale)
  end

  def description_for(locale)
    localized_value(:description, locale)
  end

  private

  def normalize_slug
    self.slug = slug.to_s.parameterize(separator: "_") if slug.present?
  end

  def assign_key
    return if slug.blank?
    return if key.present?

    self.key = "marketplace_#{slug}"
  end

  def key_matches_slug
    return if slug.blank? || key.blank?

    expected = "marketplace_#{slug}"
    return if key == expected

    errors.add(:key, :invalid)
  end

  def billing_plan_is_one_time
    return if billing_plan&.one_time?

    errors.add(:billing_plan, :invalid)
  end

  def billing_plan_has_stripe_ids
    return unless billing_plan
    return if billing_plan.stripe_product_id.present? && billing_plan.stripe_price_id.present?

    errors.add(:billing_plan, :invalid)
  end

  def slug_immutable
    return unless slug_changed?

    errors.add(:slug, :immutable)
  end

  def key_immutable
    return unless key_changed?

    errors.add(:key, :immutable)
  end

  def localized_value(prefix, locale)
    key = "#{prefix}_#{locale}"
    value = respond_to?(key) ? public_send(key) : nil
    fallback_key = "#{prefix}_en"
    value.presence || public_send(fallback_key)
  end
end
