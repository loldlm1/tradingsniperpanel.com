class RevenueSplitPayout < ApplicationRecord
  attr_accessor :as_of

  belongs_to :paid_by_admin, class_name: "User", optional: true

  enum :status, { unpaid: 0, paid: 1 }

  validates :period_key, :starts_at, :ends_at, presence: true
  validates :net_cents, :us_cents, :client_cents, presence: true, numericality: { only_integer: true }
  validates :period_key, uniqueness: { scope: [:starts_at, :ends_at] }

  def self.ransackable_associations(_auth_object = nil)
    ["paid_by_admin"]
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[created_at ends_at id paid_at paid_by_admin_id period_key starts_at status]
  end

  validate :starts_before_ends
  validate :split_matches_net
  validate :paid_details_present
  validate :paid_by_admin_is_master_admin

  scope :for_period, ->(period) { where(period_key: period.key, starts_at: period.starts_at, ends_at: period.ends_at) }

  private

  def starts_before_ends
    return if starts_at.blank? || ends_at.blank?
    return if starts_at < ends_at

    errors.add(:starts_at, :invalid)
  end

  def split_matches_net
    return if net_cents.nil? || us_cents.nil? || client_cents.nil?
    return if us_cents + client_cents == net_cents

    errors.add(:base, :invalid)
  end

  def paid_details_present
    return unless paid?

    errors.add(:paid_at, :blank) if paid_at.blank?
    errors.add(:paid_by_admin, :blank) if paid_by_admin.blank?
  end

  def paid_by_admin_is_master_admin
    return if paid_by_admin.blank?
    return if paid_by_admin.master_admin?

    errors.add(:paid_by_admin, :invalid)
  end
end
