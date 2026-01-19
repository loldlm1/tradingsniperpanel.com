class MarketplaceAsset < ApplicationRecord
  acts_as_taggable_on :tags

  has_one_attached :file

  has_many :asset_plan_entitlements, dependent: :destroy
  has_many :billing_plans, through: :asset_plan_entitlements
  has_many :addons, as: :addonable, dependent: :destroy

  enum :status, { draft: "draft", active: "active" }

  scope :active, -> { where(status: "active") }
  scope :ordered, -> { order(:sort_order, :title_en) }

  before_validation :normalize_slug, on: :create

  validates :slug, presence: true, uniqueness: true
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

  def description_markdown_for(locale)
    localized_value(:description_markdown, locale)
  end

  private

  def normalize_slug
    self.slug = slug.to_s.parameterize(separator: "_") if slug.present?
  end

  def localized_value(prefix, locale)
    key = "#{prefix}_#{locale}"
    value = respond_to?(key) ? public_send(key) : nil
    fallback_key = "#{prefix}_en"
    value.presence || public_send(fallback_key)
  end
end
