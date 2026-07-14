module Dashboard
  class DiscordPresenter
    Result = Data.define(
      :state,
      :eligible,
      :identity_label,
      :linked_at,
      :last_synced_at,
      :connectable,
      :retryable,
      :open_discord,
      :view_plans,
      :contact_support,
      :disconnectable,
      :support_url
    )

    def initialize(user:, eligibility: nil)
      @user = user
      @eligibility = eligibility
    end

    def call
      connection = user.discord_connection
      eligibility = @eligibility || Discord::VipEligibility.new(user: user).call
      state = state_for(connection, eligibility)

      Result.new(
        state: state,
        eligible: eligibility.eligible?,
        identity_label: identity_label(connection),
        linked_at: connection&.linked_at,
        last_synced_at: connection&.last_synced_at,
        connectable: state == :eligible_unlinked,
        retryable: retryable?(connection, eligibility),
        open_discord: Discord.configuration.support_url.present?,
        view_plans: !eligibility.eligible?,
        contact_support: state == :failed,
        disconnectable: connection&.connected? && !connection.disconnect_pending?,
        support_url: Discord.configuration.support_url
      )
    end

    private

    attr_reader :user

    def state_for(connection, eligibility)
      return :disabled unless Discord.enabled?
      return eligibility.eligible? ? :eligible_unlinked : :ineligible unless connection&.connected?
      return :disconnecting if connection.disconnect_pending?
      return :failed if connection.sync_status == "failed"
      if connection.membership_pending == true
        return connection.vip_role_state == "granted" ? :membership_screening : :pending_join
      end
      return :granted if eligibility.eligible? && connection.vip_role_state == "granted"
      return :removed if !eligibility.eligible? || connection.vip_role_state == "removed"

      :queued
    end

    def retryable?(connection, eligibility)
      return false unless connection&.connected?
      return false if connection.disconnect_pending?

      connection.sync_status == "failed" ||
        (eligibility.eligible? && connection.vip_role_state != "granted")
    end

    def identity_label(connection)
      return unless connection&.connected?

      connection.discord_global_name.presence || connection.discord_username.presence
    end
  end
end
