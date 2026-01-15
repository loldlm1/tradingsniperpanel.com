class Addon < ApplicationRecord
  ALLOWED_ADDONABLES = %w[ExpertAdvisor Course].freeze

  belongs_to :addonable, polymorphic: true
  belongs_to :billing_plan
  has_one :marketplace_product, through: :billing_plan

  validates :key, presence: true, uniqueness: true, format: { with: /\A[a-z0-9_]+\z/ }
  validates :billing_plan_id, uniqueness: true

  validate :billing_plan_is_one_time
  validate :billing_plan_has_stripe_ids
  validate :addonable_supported

  private

  def billing_plan_is_one_time
    return if billing_plan&.one_time?

    errors.add(:billing_plan, :invalid)
  end

  def billing_plan_has_stripe_ids
    return unless billing_plan
    return if billing_plan.stripe_product_id.present? && billing_plan.stripe_price_id.present?

    errors.add(:billing_plan, :invalid)
  end

  def addonable_supported
    return if addonable_type.in?(ALLOWED_ADDONABLES)

    errors.add(:addonable_type, :invalid)
  end
end
