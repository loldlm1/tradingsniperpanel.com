class BillingPlanPrice < ApplicationRecord
  belongs_to :billing_plan, inverse_of: :billing_plan_prices

  scope :current, -> { where(current: true) }
  scope :active, -> { where(active: true) }
  scope :retired, -> { where.not(retired_at: nil) }

  before_validation :normalize_currency

  validates :stripe_price_id, presence: true, uniqueness: true
  validates :amount_cents, numericality: { only_integer: true, greater_than: 0 }
  validates :currency, presence: true
  validates :interval_count, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true

  validate :recurrence_is_coherent
  validate :current_state_is_coherent

  def self.for_price_id(price_id)
    return if price_id.blank?

    find_by(stripe_price_id: price_id)
  end

  private

  def normalize_currency
    self.currency = currency.to_s.downcase.presence
  end

  def recurrence_is_coherent
    if interval.present?
      errors.add(:interval, :inclusion) unless interval.in?(BillingPlan::INTERVALS)
      errors.add(:interval_count, :blank) if interval_count.blank?
    elsif interval_count.present?
      errors.add(:interval, :blank)
    end
  end

  def current_state_is_coherent
    return unless current?

    errors.add(:active, :invalid) unless active?
    errors.add(:retired_at, :invalid) if retired_at.present?
  end
end
