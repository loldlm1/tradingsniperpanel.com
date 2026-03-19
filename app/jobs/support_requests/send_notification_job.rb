module SupportRequests
  class SendNotificationJob < ApplicationJob
    self.enqueue_after_transaction_commit = true

    queue_as :default

    def perform(support_request_id)
      support_request = SupportRequest.includes(:user, screenshots_attachments: :blob).find_by(id: support_request_id)
      return unless support_request

      SupportRequestsMailer.with(support_request: support_request).request_notification.deliver_now
    rescue StandardError => e
      Rails.logger.warn(
        "[SupportRequests::SendNotificationJob] failed support_request_id=#{support_request_id}: #{e.class} - #{e.message}"
      )
      raise
    end
  end
end
