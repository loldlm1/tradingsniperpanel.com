class PartnerMembership < ApplicationRecord
  belongs_to :partner_profile
  belongs_to :user
  belongs_to :referral, class_name: "Refer::Referral", optional: true

  scope :active, -> { where(ended_at: nil) }

  validates :depth, numericality: { greater_than_or_equal_to: 0 }
  validates :started_at, presence: true
  validates :user_id, uniqueness: { conditions: -> { where(ended_at: nil) }, message: "already has an active partner membership" }

  before_validation :set_started_at

  def active?
    ended_at.nil?
  end

  private

  def set_started_at
    self.started_at ||= Time.current
  end
end
