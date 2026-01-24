class Course < ApplicationRecord
  acts_as_taggable_on :tags
  has_one_attached :cover_image

  has_many :course_modules, dependent: :destroy
  has_many :course_lessons, through: :course_modules
  has_many :course_plan_entitlements, dependent: :destroy
  has_many :billing_plans, through: :course_plan_entitlements
  has_many :course_enrollments, dependent: :destroy
  has_many :addons, as: :addonable, dependent: :destroy

  scope :published, -> { where(status: "published") }
  scope :ordered, -> { order(:position, :title_en) }

  validates :slug, presence: true, uniqueness: true
  validates :status, presence: true
  validates :category, presence: true
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :title_en, :title_es, presence: true

  def self.ransackable_associations(_auth_object = nil)
    %w[tags]
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[category created_at id position slug status title_en title_es updated_at]
  end

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

  def allowed_for_tier?(tier)
    allowed = subscription_tiers
    return true if allowed.blank?

    allowed.map(&:to_s).include?(tier.to_s)
  end

  def subscription_tiers
    if course_plan_entitlements.loaded? || billing_plans.loaded?
      tiers = billing_plans.select(&:subscription?).map(&:tier)
      return tiers.compact.uniq if tiers.present?
    end

    tiers = billing_plans.subscription.distinct.pluck(:tier)
    return tiers.compact.uniq if tiers.present?

    []
  end

  private

  def localized_value(prefix, locale)
    key = "#{prefix}_#{locale}"
    value = respond_to?(key) ? public_send(key) : nil
    fallback_key = "#{prefix}_en"
    value.presence || public_send(fallback_key)
  end
end
