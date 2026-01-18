class ManualSubscription < ApplicationRecord
  STATUSES = {
    active: "active",
    expired: "expired",
    cancelled: "cancelled"
  }.freeze

  belongs_to :user
  belongs_to :billing_plan
  belongs_to :recorded_by_admin, class_name: "User"

  enum :status, STATUSES

  validates :amount_cents, numericality: { greater_than: 0 }
  validates :currency, :paid_at, :starts_at, :ends_at, presence: true

  validate :billing_plan_is_subscription
  validate :ends_after_start
  validate :no_overlapping_periods

  before_validation :assign_status_from_dates
  after_commit :enqueue_sync, on: %i[create update]

  scope :active, -> { where("ends_at > ?", Time.current).where.not(status: STATUSES[:cancelled]) }
  scope :active_at, ->(time) { where("starts_at <= ? AND ends_at >= ?", time, time).where.not(status: STATUSES[:cancelled]) }

  def self.ransackable_associations(_auth_object = nil)
    %w[billing_plan recorded_by_admin user]
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[billing_plan_id created_at ends_at id paid_at recorded_by_admin_id status user_id]
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
    return false if cancelled?
    return false if ends_at.present? && ends_at <= Time.current

    status == STATUSES[:active]
  end

  def active_for_time?(time = Time.current)
    return false if cancelled?
    return false if starts_at.blank? || ends_at.blank?

    starts_at <= time && ends_at >= time
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

  def no_overlapping_periods
    return if starts_at.blank? || ends_at.blank?

    conflict = self.class.where(user_id: user_id, billing_plan_id: billing_plan_id)
                         .where.not(id: id)
                         .where("starts_at < ? AND ends_at > ?", ends_at, starts_at)
                         .exists?
    errors.add(:base, :invalid) if conflict
  end

  def assign_status_from_dates
    return if cancelled?
    return if ends_at.blank?

    self.status = ends_at.future? ? STATUSES[:active] : STATUSES[:expired]
  end

  def enqueue_sync
    ManualSubscriptions::SyncJob.perform_later(id)
  end
end
