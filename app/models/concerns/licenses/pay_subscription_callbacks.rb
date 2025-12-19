module Licenses
  module PaySubscriptionCallbacks
    extend ActiveSupport::Concern

    included do
      after_commit :enqueue_license_sync
    end

    private

    def enqueue_license_sync
      return unless customer&.owner.is_a?(User)

      cancel_other_active_subscriptions
      Licenses::SyncSubscriptionJob.perform_later(id)
    end

    def cancel_other_active_subscriptions
      siblings = customer.subscriptions.active.where.not(id: id)
      siblings.find_each do |subscription|
        next unless subscription.respond_to?(:cancel_now!)

        subscription.cancel_now!
      rescue StandardError => e
        Rails.logger.warn("[Licenses::PaySubscriptionCallbacks] failed to cancel duplicate subscription #{subscription.id}: #{e.class} - #{e.message}")
      end
    end
  end
end
