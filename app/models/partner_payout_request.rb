class PartnerPayoutRequest < ApplicationRecord
  belongs_to :partner_profile
  has_many :partner_commissions, foreign_key: :payout_request_id, dependent: :nullify

  enum :status, { pending: 0, paid: 1, cancelled: 2 }
  enum :notification_status, { queued: 0, sent: 1, failed: 2 }, prefix: :notification

  validates :total_cents, numericality: { greater_than_or_equal_to: 0 }
  validates :notification_status, presence: true

  scope :awaiting_notification_retry, -> { pending.notification_failed }

  def self.ransackable_associations(_auth_object = nil)
    ["partner_commissions", "partner_profile"]
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[
      created_at
      id
      note
      notification_failed_at
      notification_sent_at
      notification_status
      paid_at
      partner_profile_id
      payment_reference
      requested_at
      status
      total_cents
      updated_at
    ]
  end

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

  def mark_notification_queued!
    update!(
      notification_status: :queued,
      notification_failed_at: nil,
      notification_failure_message: nil
    )
  end

  def mark_notification_sent!
    update!(
      notification_status: :sent,
      notification_sent_at: Time.current,
      notification_failed_at: nil,
      notification_failure_message: nil
    )
  end

  def mark_notification_failed!(message:)
    update!(
      notification_status: :failed,
      notification_failed_at: Time.current,
      notification_failure_message: message.to_s.truncate(500)
    )
  end

  def notification_retryable?
    pending? && notification_failed?
  end

  def request_locked?
    pending? && !notification_failed?
  end
end
