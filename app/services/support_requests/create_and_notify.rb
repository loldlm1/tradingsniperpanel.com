module SupportRequests
  class CreateAndNotify
    Result = Struct.new(:success?, :support_request, :error, keyword_init: true)

    def initialize(support_request:)
      @support_request = support_request
    end

    def call
      return Result.new(success?: false, support_request: @support_request) unless @support_request.valid?

      SupportRequest.transaction do
        @support_request.save!
        SupportRequests::SendNotificationJob.perform_later(@support_request.id)
      end

      Rails.logger.info(
        "[SupportRequests::CreateAndNotify] submitted support_request_id=#{@support_request.id} user_id=#{@support_request.user_id}"
      )

      Result.new(success?: true, support_request: @support_request)
    rescue StandardError => e
      Rails.logger.error(
        "[SupportRequests::CreateAndNotify] failed user_id=#{@support_request.user_id.inspect}: #{e.class} - #{e.message}"
      )
      @support_request.errors.add(:base, I18n.t("dashboard.support_submit_error"))
      @support_request.purge_uploaded_screenshots unless @support_request.persisted?
      Result.new(success?: false, support_request: @support_request, error: e)
    end
  end
end
