class License < ApplicationRecord
  STATUSES = {
    trial: "trial",
    active: "active",
    expired: "expired",
    revoked: "revoked"
  }.freeze

  belongs_to :user
  belongs_to :expert_advisor
  has_many :broker_accounts, dependent: :destroy

  enum :status, STATUSES

  validates :encrypted_key, presence: true
  validates :status, inclusion: { in: STATUSES.values }
  validates :user_id, uniqueness: { scope: :expert_advisor_id }

  scope :active_or_trial, -> { where(status: %w[active trial]) }

  def expired_by_time?
    return true if revoked? || expired?
    return trial_expired? if trial?
    return period_expired? if active?

    false
  end

  def active_for_request?
    return false if expired_by_time?

    active? || trial?
  end

  def effective_expires_at
    trial? ? trial_ends_at : expires_at
  end

  def period_expired?
    expires_at.present? && expires_at <= Time.current
  end

  def trial_expired?
    trial_ends_at.present? && trial_ends_at <= Time.current
  end
end
