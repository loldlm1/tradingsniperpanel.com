class BillingPlan < ApplicationRecord
  INTERVALS = %w[day week month year].freeze

  has_many :billing_plan_entitlements, dependent: :destroy
  has_many :course_plan_entitlements, dependent: :destroy
  has_many :asset_plan_entitlements, dependent: :destroy
  has_many :expert_advisors, through: :billing_plan_entitlements
  has_many :courses, through: :course_plan_entitlements
  has_many :marketplace_assets, through: :asset_plan_entitlements
  has_one :addon, dependent: :destroy
  has_one :marketplace_product, dependent: :nullify
  has_many :marketplace_purchases, dependent: :restrict_with_exception
  has_many :manual_transactions, dependent: :restrict_with_exception
  has_many :manual_subscriptions, dependent: :restrict_with_exception

  enum :kind, { subscription: "subscription", one_time: "one_time" }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:sort_order, :name) }

  def self.for_key(key)
    return nil if key.blank?

    find_by(key: key)
  end

  def self.for_price_id(price_id)
    return nil if price_id.blank?

    find_by(stripe_price_id: price_id)
  end

  def self.for_product_id(product_id)
    return nil if product_id.blank?

    find_by(stripe_product_id: product_id)
  end

  def self.subscription_tiers
    plans = subscription.active.where.not(tier: nil)
    return [] if plans.empty?

    grouped = plans.group_by(&:tier)
    ordered = grouped.values.map do |tier_plans|
      tier_plans.min_by { |plan| [plan.sort_order.to_i, plan.amount_cents.to_i] }
    end.compact

    ordered.sort_by { |plan| [plan.sort_order.to_i, plan.amount_cents.to_i, plan.tier.to_s] }
  end

  validates :key, presence: true, uniqueness: true, format: { with: /\A[a-z0-9_]+\z/ }
  validates :name, presence: true, uniqueness: true
  validates :kind, presence: true
  validates :amount_cents, presence: true, numericality: { greater_than: 0 }
  validates :currency, presence: true
  validates :interval_count, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true

  validate :subscription_fields
  validate :key_matches_subscription

  def interval_key
    return nil unless subscription?

    Billing::IntervalLabeler.interval_key(interval:, interval_count:)
  end

  def interval_label
    return nil unless subscription?

    Billing::IntervalLabeler.label(interval:, interval_count:)
  end

  def billed_label
    return nil unless subscription?

    Billing::IntervalLabeler.billed_label(interval:, interval_count:)
  end

  def per_label
    return nil unless subscription?

    Billing::IntervalLabeler.per_label(interval:, interval_count:)
  end

  def interval_sort_key
    Billing::IntervalLabeler.sort_key(interval:, interval_count:)
  end

  private

  def subscription_fields
    return unless subscription?

    errors.add(:tier, :blank) if tier.blank?
    errors.add(:interval, :blank) if interval.blank?
    errors.add(:interval_count, :blank) if interval_count.blank?
    return if interval.blank?

    errors.add(:interval, :inclusion) unless interval.in?(INTERVALS)
  end

  def key_matches_subscription
    return unless subscription?
    return if tier.blank? || interval_key.blank? || key.blank?

    expected = "#{tier}_#{interval_key}"
    return if key == expected

    errors.add(:key, :invalid)
  end
end
