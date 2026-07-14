module Discord
  class SyncVipRoleJob < ApplicationJob
    class RetryableError < StandardError; end

    queue_as :default
    retry_on RetryableError, wait: 5.seconds, attempts: 5

    def self.enqueue(connection_id)
      return false unless Discord.enabled?

      connection = DiscordConnection.find_by(id: connection_id)
      return false if connection&.discord_user_id.blank?

      unless connection.sync_status == "syncing"
        connection.update_columns(sync_status: "queued", updated_at: Time.current)
      end
      perform_later(connection.id)
      true
    end

    def perform(connection_id)
      return unless Discord.enabled?
      return unless DiscordConnection.where(id: connection_id).where.not(discord_user_id: nil).exists?

      result = SyncVipRole.new(connection_id: connection_id).call
      schedule(connection_id, result.retry_after) if result.rate_limited?
      raise RetryableError if result.retryable?

      self.class.enqueue(connection_id) if result.follow_up?
    end

    private

    def schedule(connection_id, retry_after)
      connection = DiscordConnection.find_by(id: connection_id)
      return unless connection&.discord_user_id.present?

      connection.update_columns(sync_status: "queued", updated_at: Time.current)
      self.class.set(wait: [ retry_after.to_f, 1.0 ].max.seconds).perform_later(connection_id)
    end
  end
end
