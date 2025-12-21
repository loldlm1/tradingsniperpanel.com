class PartnerPayoutRequest < ApplicationRecord
  belongs_to :partner_profile
  has_many :partner_commissions, foreign_key: :payout_request_id, dependent: :nullify

  enum :status, { pending: 0, paid: 1, cancelled: 2 }

  validates :total_cents, numericality: { greater_than_or_equal_to: 0 }

  def mark_paid!(payment_reference: nil)
    transaction do
      update!(status: :paid, paid_at: Time.current, payment_reference: payment_reference)
      partner_commissions.update_all(status: PartnerCommission.statuses[:paid], updated_at: Time.current)
    end
  end

  def mark_cancelled!(note: nil)
    transaction do
      update!(status: :cancelled, note: note)
      partner_commissions.update_all(status: PartnerCommission.statuses[:cancelled], updated_at: Time.current)
    end
  end
end
