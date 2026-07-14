module ManualSubscriptions
  class SyncJob < ApplicationJob
    queue_as :default

    retry_on StandardError, wait: 5.seconds, attempts: 3

    def perform(manual_subscription_id)
      manual_subscription = ManualSubscription.find_by(id: manual_subscription_id)
      Licenses::ManualSubscriptionSync.new(manual_subscription_id: manual_subscription_id).call
      return unless Discord.enabled?

      connection = manual_subscription&.user&.discord_connection
      Discord::SyncVipRoleJob.enqueue(connection.id) if connection
    end
  end
end
