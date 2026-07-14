module Discord
  class ReconcileVipRolesJob < ApplicationJob
    BATCH_SIZE = 100

    queue_as :default

    def perform
      return unless Discord.enabled?

      DiscordConnection.reconcilable.find_each(batch_size: BATCH_SIZE) do |connection|
        SyncVipRoleJob.enqueue(connection.id)
      end
    end
  end
end
