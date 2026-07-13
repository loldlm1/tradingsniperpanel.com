class ManualSubscription < ApplicationRecord
  attr_accessor :request_id, :user_lookup

  STATUSES = {
    active: "active",
    expired: "expired",
    cancelled: "cancelled",
    superseded: "superseded"
  }.freeze
  PAYMENT_STATUSES = {
    complimentary: "complimentary",
    pending: "pending",
    paid: "paid"
  }.freeze

  belongs_to :user
  belongs_to :billing_plan
  belongs_to :recorded_by_admin, class_name: "User"
  belongs_to :superseded_by_pay_subscription, class_name: "Pay::Subscription", optional: true

  enum :status, STATUSES
  enum :payment_status, PAYMENT_STATUSES, prefix: :payment

  validates :amount_cents, numericality: { greater_than_or_equal_to: 0 }
  validates :granted_days, numericality: { only_integer: true, greater_than: 0 }
  validates :currency, :starts_at, :ends_at, presence: true
  validates :paid_at, presence: true, if: :payment_paid?

  validate :billing_plan_is_subscription
  validate :ends_after_start
  validate :payment_details_are_coherent
  validate :no_overlapping_periods
  validate :no_active_pay_subscription, if: :active?

  before_validation :assign_status_from_dates
  after_commit :enqueue_sync, on: %i[create update]

  scope :active, lambda {
    where("ends_at > ?", Time.current).where.not(status: [ STATUSES[:cancelled], STATUSES[:superseded] ])
  }
  scope :active_at, lambda { |time|
    where("starts_at <= ? AND ends_at >= ?", time, time)
      .where.not(status: [ STATUSES[:cancelled], STATUSES[:superseded] ])
  }
  scope :not_superseded, -> { where.not(status: STATUSES[:superseded]) }

  def self.ransackable_associations(_auth_object = nil)
    %w[billing_plan recorded_by_admin superseded_by_pay_subscription user]
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[
      billing_plan_id
      created_at
      ends_at
      granted_days
      id
      paid_at
      payment_status
      recorded_by_admin_id
      status
      superseded_at
      superseded_by_pay_subscription_id
      user_id
    ]
  end

  def processor_plan
    billing_plan&.stripe_price_id || billing_plan&.key
  end

  def current_period_end
    ends_at
  end

  def trial_ends_at
    nil
  end

  def past_due?
    false
  end

  def unpaid?
    false
  end

  def active?
    return false if cancelled? || superseded?
    return false if ends_at.present? && ends_at <= Time.current

    status == STATUSES[:active]
  end

  def active_for_time?(time = Time.current)
    return false if cancelled? || superseded?
    return false if starts_at.blank? || ends_at.blank?

    starts_at <= time && ends_at >= time
  end

  def revocable?(at = Time.current)
    !cancelled? && !superseded? && ends_at.present? && ends_at > at
  end

  def settled_amount_cents
    payment_paid? ? amount_cents : 0
  end

  def supersede_with!(pay_subscription:, at: Time.current)
    with_lock do
      return false if superseded?

      update!(
        status: STATUSES[:superseded],
        superseded_at: at,
        superseded_by_pay_subscription: pay_subscription
      )
    end

    true
  end

  def self.supersede_for_stripe!(user:, pay_subscription:, at: Time.current)
    transaction do
      where(user: user)
        .where.not(status: [ STATUSES[:cancelled], STATUSES[:superseded] ])
        .where("ends_at > ?", at)
        .reorder(:id)
        .lock
        .filter_map do |manual_subscription|
          manual_subscription.id if manual_subscription.supersede_with!(pay_subscription: pay_subscription, at: at)
        end
    end
  end

  private

  def billing_plan_is_subscription
    return if billing_plan&.subscription?

    errors.add(:billing_plan, :invalid)
  end

  def ends_after_start
    return if starts_at.blank? || ends_at.blank?
    return if ends_at > starts_at

    errors.add(:ends_at, :invalid)
  end

  def payment_details_are_coherent
    if payment_complimentary?
      errors.add(:amount_cents, :invalid) unless amount_cents.to_i.zero?
      errors.add(:paid_at, :invalid) if paid_at.present?
    elsif payment_pending?
      errors.add(:paid_at, :invalid) if paid_at.present?
    elsif payment_paid?
      errors.add(:amount_cents, :greater_than, count: 0) unless amount_cents.to_i.positive?
    end
  end

  def no_overlapping_periods
    return if starts_at.blank? || ends_at.blank?

    conflict = self.class.where(user_id: user_id)
                         .where.not(status: [ STATUSES[:cancelled], STATUSES[:superseded] ])
                         .where.not(id: id)
                         .where("starts_at < ? AND ends_at > ?", ends_at, starts_at)
                         .exists?
    errors.add(:base, :invalid) if conflict
  end

  def assign_status_from_dates
    return if cancelled? || superseded?
    return if ends_at.blank?

    self.status = ends_at.future? ? STATUSES[:active] : STATUSES[:expired]
  end

  def no_active_pay_subscription
    return unless user

    result = Billing::ActiveSubscriptionFinder.new(user: user).call
    errors.add(:base, :billing_conflict) if result.stripe?
  end

  def enqueue_sync
    ManualSubscriptions::SyncJob.perform_later(id)
  end
end
