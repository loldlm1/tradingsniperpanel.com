module Discord
  class OauthCallbacksController < ApplicationController
    before_action :authenticate_user!

    def show
      return redirect_with_error(:disabled) unless Discord.enabled?

      payload = oauth_state.consume(params[:state])
      return redirect_with_error(:denied, locale: payload.locale) if params[:error].present?

      LinkAccount.new(user: current_user, code: params.require(:code)).call
      redirect_to dashboard_discord_connection_path(locale: payload.locale),
                  notice: t("dashboard.discord.notices.connected", locale: payload.locale)
    rescue OauthState::ExpiredState
      redirect_with_error(:expired)
    rescue OauthState::InvalidState, ActionController::ParameterMissing
      redirect_with_error(:invalid_state)
    rescue LinkAccount::IdentityInUse
      redirect_with_error(:identity_in_use, locale: payload&.locale)
    rescue LinkAccount::AlreadyConnected
      redirect_with_error(:already_connected, locale: payload&.locale)
    rescue LinkAccount::Ineligible
      redirect_with_error(:ineligible, locale: payload&.locale)
    rescue Discord::Error, ActiveRecord::RecordInvalid
      redirect_with_error(:provider_failed, locale: payload&.locale)
    end

    private

    def oauth_state
      @oauth_state ||= OauthState.new(session: session)
    end

    def redirect_with_error(key, locale: nil)
      redirect_to dashboard_discord_connection_path(locale: locale.presence || I18n.locale),
                  alert: t("dashboard.discord.errors.#{key}", locale: locale.presence || I18n.locale)
    end
  end
end
