module Partners
  module PayChargeCallbacks
    extend ActiveSupport::Concern

    included do
      after_commit :enqueue_partner_commission_build, on: :create
    end

    private

    def enqueue_partner_commission_build
      Partners::BuildCommissionsJob.perform_later(id)
    rescue StandardError => e
      Rails.logger.warn("[Partners::PayChargeCallbacks] failed to enqueue commission build for pay_charge_id=#{id}: #{e.class} - #{e.message}")
    end
  end
end
