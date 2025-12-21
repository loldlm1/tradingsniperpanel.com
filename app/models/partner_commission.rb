class PartnerCommission < ApplicationRecord
  belongs_to :partner_profile
  belongs_to :partner_membership
  belongs_to :referred_user, class_name: "User"
  belongs_to :referral, class_name: "Refer::Referral", optional: true
  belongs_to :pay_charge, class_name: "Pay::Charge", optional: true
  belongs_to :pay_subscription, class_name: "Pay::Subscription", optional: true
  belongs_to :payout_request, class_name: "PartnerPayoutRequest", optional: true

  enum :commission_kind, { initial: 0, renewal: 1 }
  enum :status, { pending: 0, requested: 1, paid: 2, cancelled: 3 }

  validates :amount_cents, numericality: { greater_than_or_equal_to: 0 }
  validates :occurred_at, presence: true
  validates :currency, presence: true

  scope :pending_or_requested, -> { where(status: [:pending, :requested]) }
end
