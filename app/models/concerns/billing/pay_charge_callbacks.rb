module Billing
  module PayChargeCallbacks
    extend ActiveSupport::Concern

    included do
      after_commit :enqueue_one_time_entitlement_sync, on: :create
    end

    private

    def enqueue_one_time_entitlement_sync
      Licenses::SyncOneTimePurchaseJob.perform_later(id)
    rescue StandardError => e
      Rails.logger.warn("[Billing::PayChargeCallbacks] failed to enqueue pay_charge_id=#{id}: #{e.class} - #{e.message}")
    end
  end
end
