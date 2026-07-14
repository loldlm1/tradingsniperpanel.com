module Discord
  class SyncVipRole
    LEASE_DURATION = 5.minutes
    Result = Data.define(:outcome, :retry_after, :follow_up) do
      def rate_limited?
        outcome == :rate_limited
      end

      def retryable?
        outcome == :retryable_failure
      end

      def follow_up?
        follow_up == true
      end
    end

    def initialize(
      connection_id:,
      client: Client.new,
      eligibility_class: VipEligibility,
      clock: Time,
      logger: Rails.logger
    )
      @connection_id = connection_id
      @client = client
      @eligibility_class = eligibility_class
      @clock = clock
      @logger = logger
    end

    def call
      return result(:disabled) unless Discord.enabled?

      claim = claim_lease
      return claim if claim.is_a?(Result)

      connection = DiscordConnection.includes(:user).find_by(id: connection_id)
      return result(:not_connected) unless same_identity?(connection, claim)

      desired_granted = desired_granted?(connection)
      desired_granted ? client.add_vip_role(user_id: claim[:discord_user_id]) : client.remove_vip_role(user_id: claim[:discord_user_id])

      mark_success(claim, desired_granted)
      result(
        desired_granted ? :granted : :removed,
        follow_up: follow_up_required?(claim, desired_granted)
      )
    rescue RateLimitedError => e
      mark_failure(claim, e.code) if claim.is_a?(Hash)
      result(:rate_limited, retry_after: e.retry_after || 5.0)
    rescue TransportError, ServerError => e
      mark_failure(claim, e.code) if claim.is_a?(Hash)
      result(:retryable_failure)
    rescue Error => e
      mark_failure(claim, e.code) if claim.is_a?(Hash)
      result(:operational_failure)
    rescue StandardError
      mark_failure(claim, :internal_error) if claim.is_a?(Hash)
      raise
    end

    private

    attr_reader :connection_id, :client, :eligibility_class, :clock, :logger

    def claim_lease
      connection = DiscordConnection.find_by(id: connection_id)
      return result(:not_found) unless connection

      connection.with_lock do
        connection.reload
        return result(:not_connected) if connection.discord_user_id.blank?
        return result(:lease_held) if live_lease?(connection)

        now = clock.now
        connection.update_columns(
          sync_status: "syncing",
          sync_started_at: now,
          last_error_code: nil,
          last_error_at: nil,
          updated_at: now
        )
        {
          connection_id: connection.id,
          discord_user_id: connection.discord_user_id
        }
      end
    end

    def live_lease?(connection)
      connection.sync_status == "syncing" &&
        connection.sync_started_at.present? &&
        connection.sync_started_at > clock.now - LEASE_DURATION
    end

    def desired_granted?(connection)
      return false if connection.disconnect_pending?

      eligibility_class.new(user: connection.user).call.eligible?
    end

    def same_identity?(connection, claim)
      connection&.discord_user_id == claim[:discord_user_id]
    end

    def mark_success(claim, granted)
      now = clock.now
      DiscordConnection.where(
        id: claim[:connection_id],
        discord_user_id: claim[:discord_user_id]
      ).update_all(
        vip_role_state: granted ? "granted" : "removed",
        sync_status: "idle",
        sync_started_at: nil,
        last_synced_at: now,
        last_error_code: nil,
        last_error_at: nil,
        updated_at: now
      )
    end

    def mark_failure(claim, code)
      now = clock.now
      DiscordConnection.where(
        id: claim[:connection_id],
        discord_user_id: claim[:discord_user_id]
      ).update_all(
        sync_status: "failed",
        sync_started_at: nil,
        last_error_code: code.to_s,
        last_error_at: now,
        updated_at: now
      )
      logger.warn("Discord VIP sync failed connection_id=#{claim[:connection_id]} code=#{code}")
    end

    def follow_up_required?(claim, previous_desired_granted)
      connection = DiscordConnection.includes(:user).find_by(id: claim[:connection_id])
      return true unless same_identity?(connection, claim)

      desired_granted?(connection) != previous_desired_granted
    end

    def result(outcome, retry_after: nil, follow_up: false)
      Result.new(outcome: outcome, retry_after: retry_after, follow_up: follow_up)
    end
  end
end
