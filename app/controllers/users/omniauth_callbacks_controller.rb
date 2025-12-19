class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def google_oauth2
    auth = request.env["omniauth.auth"]
    result = Auth::GoogleOauth.new(auth:, locale: I18n.locale).call

    if result.user.persisted?
      refer(result.user) if result.status == :created
      set_flash_message(:notice, :success, kind: "Google") if is_navigational_format?
      sign_in_and_redirect result.user, event: :authentication
    else
      redirect_to new_user_session_path, alert: failure_message(result.user)
    end
  rescue StandardError => e
    Rails.logger.error(
      {
        message: "Google OAuth callback error",
        error: e.message,
        provider: auth&.provider,
        uid: auth&.uid
      }.to_json
    )

    redirect_to new_user_session_path, alert: t("devise.omniauth_callbacks.failure", kind: "Google", reason: "unexpected error")
  end

  def failure
    redirect_to new_user_session_path, alert: t("devise.omniauth_callbacks.failure", kind: failure_strategy, reason: failure_reason)
  end

  private

  def failure_message(user)
    reason = user.errors.full_messages.to_sentence.presence || "could not sign in"
    t("devise.omniauth_callbacks.failure", kind: "Google", reason:)
  end

  def failure_strategy
    params[:strategy].presence || "Google"
  end

  def failure_reason
    params[:error_description].presence || params[:error].presence || "authentication failed"
  end
end
