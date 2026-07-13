class License < ApplicationRecord
  STATUSES = {
    trial: "trial",
    active: "active",
    expired: "expired",
    revoked: "revoked"
  }.freeze
  LIFETIME_EXPIRES_AT = Time.utc(2099, 12, 31, 23, 59, 59)
  MAX_TOKEN_VERSION = 2_147_483_647

  belongs_to :user
  belongs_to :expert_advisor
  has_many :broker_accounts, dependent: :destroy
  has_many :license_lane_magic_numbers, dependent: :destroy
  has_many :license_instance_magic_numbers, dependent: :destroy

  enum :status, STATUSES
  enum :access_source, { subscription: "subscription", one_time: "one_time" }, prefix: true

  validates :encrypted_key, presence: true
  validates :status, inclusion: { in: STATUSES.values }
  validates :token_version,
            numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: MAX_TOKEN_VERSION }
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

  def key_expires_at
    return trial_ends_at if trial?
    return expires_at if expires_at.present?
    return LIFETIME_EXPIRES_AT if access_source_one_time?

    nil
  end

  def token_generation_attributes(token_version: self.token_version)
    {
      email: user.email,
      ea_id: expert_advisor.ea_id,
      expires_at: key_expires_at,
      token_version: token_version
    }
  end

  def period_expired?
    expires_at.present? && expires_at <= Time.current
  end

  def trial_expired?
    trial_ends_at.present? && trial_ends_at <= Time.current
  end
end
