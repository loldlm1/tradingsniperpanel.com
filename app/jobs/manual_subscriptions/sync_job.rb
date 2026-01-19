module ManualSubscriptions
  class SyncJob < ApplicationJob
    queue_as :default

    retry_on StandardError, wait: 5.seconds, attempts: 3

    def perform(manual_subscription_id)
      Licenses::ManualSubscriptionSync.new(manual_subscription_id: manual_subscription_id).call
    end
  end
end
