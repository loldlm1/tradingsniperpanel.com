module Partners
  class PayoutRequestor
    def initialize(partner_profile:, logger: Rails.logger)
      @partner_profile = partner_profile
      @logger = logger
    end

    def call
      pending_commissions = partner_profile.partner_commissions.pending
      return if pending_commissions.empty?

      PartnerPayoutRequest.transaction do
        total_cents = pending_commissions.sum(:amount_cents)
        request = PartnerPayoutRequest.create!(
          partner_profile: partner_profile,
          status: :pending,
          total_cents: total_cents,
          requested_at: Time.current
        )

        pending_commissions.update_all(status: PartnerCommission.statuses[:requested], payout_request_id: request.id, updated_at: Time.current)

        request
      end
    rescue StandardError => e
      logger.warn("[Partners::PayoutRequestor] failed partner_profile_id=#{partner_profile&.id}: #{e.class} - #{e.message}")
      nil
    end

    private

    attr_reader :partner_profile, :logger
  end
end
