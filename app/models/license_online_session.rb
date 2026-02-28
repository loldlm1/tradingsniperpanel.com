class LicenseOnlineSession < ApplicationRecord
  ENTITLEMENT_SOURCES = {
    subscription: "subscription",
    one_time: "one_time"
  }.freeze
  ACCOUNT_TYPES = {
    real: "real",
    demo: "demo"
  }.freeze

  belongs_to :user
  belongs_to :expert_advisor

  enum :entitlement_source, ENTITLEMENT_SOURCES, prefix: true
  enum :account_type, ACCOUNT_TYPES, prefix: true

  validates :company, presence: true
  validates :account_number, presence: true, numericality: { only_integer: true }
  validates :account_type, presence: true
  validates :entitlement_source, presence: true
  validates :last_seen_at, presence: true
  validates :account_number, uniqueness: {
    scope: %i[user_id expert_advisor_id company account_type],
    message: :taken
  }

  before_validation :normalize_company

  scope :active_since, ->(cutoff) { where("last_seen_at >= ?", cutoff) }

  private

  def normalize_company
    self.company = company.to_s.strip.downcase
  end
end
