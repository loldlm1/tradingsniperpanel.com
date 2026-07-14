module Discord
  class LinkAccount
    class AlreadyConnected < StandardError; end
    class IdentityInUse < StandardError; end
    class Ineligible < StandardError; end

    Result = Data.define(:connection)

    def initialize(
      user:,
      code:,
      client: Client.new,
      eligibility_class: VipEligibility,
      now: Time.current
    )
      @user = user
      @code = code.to_s
      @client = client
      @eligibility_class = eligibility_class
      @now = now
    end

    def call
      raise Ineligible unless eligibility_class.new(user: user).call.eligible?
      raise AlreadyConnected if user.discord_connection&.discord_user_id.present?

      oauth = client.exchange_code(code: code)
      identity = client.current_user(access_token: oauth.fetch(:access_token))
      ensure_identity_available!(identity.fetch(:id))
      membership = client.add_guild_member(
        user_id: identity.fetch(:id),
        access_token: oauth.fetch(:access_token)
      )

      connection = persist_connection(identity, membership)
      SyncVipRoleJob.enqueue(connection.id)
      Result.new(connection: connection)
    rescue ActiveRecord::RecordNotUnique
      raise IdentityInUse
    end

    private

    attr_reader :user, :code, :client, :eligibility_class, :now

    def ensure_identity_available!(discord_user_id)
      return unless DiscordConnection.where(discord_user_id: discord_user_id).where.not(user_id: user.id).exists?

      raise IdentityInUse
    end

    def persist_connection(identity, membership)
      DiscordConnection.transaction do
        user.lock!
        connection = DiscordConnection.lock.find_or_initialize_by(user: user)
        raise AlreadyConnected if connection.discord_user_id.present?

        ensure_identity_available!(identity.fetch(:id))
        connection.assign_attributes(
          discord_user_id: identity.fetch(:id),
          discord_username: identity[:username],
          discord_global_name: identity[:global_name],
          linked_at: now,
          disconnect_requested_at: nil,
          disconnected_at: nil,
          membership_pending: membership.membership_pending,
          vip_role_state: "unknown",
          sync_status: "idle",
          sync_started_at: nil,
          last_synced_at: nil,
          last_error_code: nil,
          last_error_at: nil
        )
        connection.save!
        connection
      end
    end
  end
end
