class PartnerProfile < ApplicationRecord
  belongs_to :user
  has_many :partner_memberships, dependent: :destroy
  has_many :partner_commissions, dependent: :destroy
  has_many :partner_payout_requests, dependent: :destroy

  enum :payout_mode, { once_paid: 0, concurrent: 1 }

  scope :active, -> { where(active: true) }

  validates :discount_percent, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }, allow_nil: true
  validates :payout_mode, presence: true

  before_validation :set_defaults

  def active?
    active
  end

  def discount_percent_or_default
    discount_percent.presence || default_discount_percent
  end

  private

  def set_defaults
    self.discount_percent = default_discount_percent if discount_percent.nil?
    self.payout_mode ||= :once_paid
    self.started_at ||= Time.current
    self.active = true if active.nil?
  end

  def default_discount_percent
    ENV.fetch("REFER_DEFAULT_DISCOUNT_PERCENT", "0").to_i
  end
end
