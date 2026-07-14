module Discord
  class RequestUnlink
    Result = Data.define(:status, :connection)

    def initialize(user:, now: Time.current)
      @user = user
      @now = now
    end

    def call
      return result(:disabled) unless Discord.enabled?

      connection = user.discord_connection
      return result(:already_disconnected) if connection&.discord_user_id.blank?

      connection.with_lock do
        connection.reload
        return result(:already_disconnected, connection) if connection.discord_user_id.blank?

        connection.update!(disconnect_requested_at: connection.disconnect_requested_at || now)
      end
      SyncVipRoleJob.enqueue(connection.id)
      result(:pending, connection)
    end

    private

    attr_reader :user, :now

    def result(status, connection = nil)
      Result.new(status: status, connection: connection)
    end
  end
end
