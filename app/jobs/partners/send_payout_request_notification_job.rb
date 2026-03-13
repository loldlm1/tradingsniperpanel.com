module Partners
  class SendPayoutRequestNotificationJob < ApplicationJob
    queue_as :default

    def perform(partner_payout_request_id)
      request = PartnerPayoutRequest.includes(partner_profile: :user).find_by(id: partner_payout_request_id)
      return unless request

      request.with_lock do
        return if request.notification_sent?
        return unless request.pending?
      end

      PartnerPayoutRequestsMailer.with(partner_payout_request: request).request_notification.deliver_now
      request.mark_notification_sent!
    rescue StandardError => e
      request&.mark_notification_failed!(message: e.message)
      Rails.logger.warn(
        "[Partners::SendPayoutRequestNotificationJob] failed request_id=#{partner_payout_request_id}: #{e.class} - #{e.message}"
      )
    end
  end
end
