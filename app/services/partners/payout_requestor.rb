module Partners
  class PayoutRequestor
    MINIMUM_PAYOUT_CENTS = 20_000

    Result = Struct.new(:status, :request, :total_cents, :errors, keyword_init: true) do
      def ok?
        status.in?(%i[created retried already_pending])
      end
    end

    def initialize(partner_profile:, logger: Rails.logger)
      @partner_profile = partner_profile
      @logger = logger
    end

    def call
      return Result.new(status: :invalid_profile, errors: ["partner profile is required"]) unless partner_profile.is_a?(PartnerProfile)

      existing_request = pending_request
      return handle_existing_request(existing_request) if existing_request

      pending_commissions = partner_profile.partner_commissions.pending.order(:id)
      return Result.new(status: :no_commissions, total_cents: 0) if pending_commissions.empty?

      total_cents = pending_commissions.sum(:amount_cents)
      return Result.new(status: :below_minimum, total_cents:) if total_cents < MINIMUM_PAYOUT_CENTS

      request = PartnerPayoutRequest.transaction do
        created_request = PartnerPayoutRequest.create!(
          partner_profile: partner_profile,
          status: :pending,
          notification_status: :queued,
          total_cents: total_cents,
          requested_at: Time.current
        )

        pending_commissions.update_all(
          status: PartnerCommission.statuses[:requested],
          payout_request_id: created_request.id,
          updated_at: Time.current
        )

        created_request
      end

      enqueue_notification!(request)
      Result.new(status: :created, request:, total_cents:)
    rescue StandardError => e
      logger.warn("[Partners::PayoutRequestor] failed partner_profile_id=#{partner_profile&.id}: #{e.class} - #{e.message}")
      Result.new(status: :error, errors: [e.message])
    end

    private

    attr_reader :partner_profile, :logger

    def pending_request
      partner_profile.partner_payout_requests.pending.order(created_at: :desc).first
    end

    def handle_existing_request(request)
      return retry_notification!(request) if request.notification_retryable?

      Result.new(status: :already_pending, request:, total_cents: request.total_cents)
    end

    def retry_notification!(request)
      request.with_lock do
        return Result.new(status: :already_pending, request:, total_cents: request.total_cents) unless request.notification_retryable?

        request.mark_notification_queued!
      end

      enqueue_notification!(request)
      Result.new(status: :retried, request:, total_cents: request.total_cents)
    rescue StandardError => e
      request.mark_notification_failed!(message: e.message)
      Result.new(status: :notification_failed, request:, total_cents: request.total_cents, errors: [e.message])
    end

    def enqueue_notification!(request)
      Partners::SendPayoutRequestNotificationJob.perform_later(request.id)
    rescue StandardError => e
      request.mark_notification_failed!(message: e.message)
      raise
    end
  end
end
