module Licenses
  module PaySubscriptionCallbacks
    extend ActiveSupport::Concern

    included do
      after_commit :enqueue_license_sync
    end

    private

    def enqueue_license_sync
      return unless customer&.owner.is_a?(User)

      Licenses::SyncSubscriptionJob.perform_later(id)
    end
  end
end
