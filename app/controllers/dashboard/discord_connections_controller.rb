require "uri"

module Dashboard
  class DiscordConnectionsController < ApplicationController
    layout "dashboard"

    before_action :authenticate_user!

    def show
      @discord = DiscordPresenter.new(user: current_user).call
    end

    def authorize
      return redirect_unavailable unless Discord.enabled?
      return redirect_unavailable unless Discord::VipEligibility.new(user: current_user).call.eligible?
      return redirect_unavailable if current_user.discord_connection&.discord_user_id.present?

      state = Discord::OauthState.new(session: session).issue(locale: I18n.locale)
      redirect_to authorization_url(state), allow_other_host: true
    end

    def retry
      connection = current_user.discord_connection
      if connection && Discord::SyncVipRoleJob.enqueue(connection.id)
        redirect_to dashboard_discord_connection_path, notice: t("dashboard.discord.notices.retry_queued")
      else
        redirect_unavailable
      end
    end

    def unlink
      result = Discord::RequestUnlink.new(user: current_user).call
      if result.status == :pending
        redirect_to dashboard_discord_connection_path, notice: t("dashboard.discord.notices.unlink_requested")
      else
        redirect_unavailable
      end
    end

    private

    def authorization_url(state)
      query = URI.encode_www_form(
        client_id: Discord.configuration.client_id,
        redirect_uri: Discord.configuration.redirect_uri,
        response_type: "code",
        scope: "identify guilds.join",
        state: state
      )
      "https://discord.com/oauth2/authorize?#{query}"
    end

    def redirect_unavailable
      redirect_to dashboard_discord_connection_path, alert: t("dashboard.discord.errors.action_unavailable")
    end
  end
end
