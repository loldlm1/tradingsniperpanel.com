class ApplicationController < ActionController::Base
  set_referral_cookie
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :set_locale
  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :capture_desired_plan, if: -> { request.format.html? }

  def after_sign_in_path_for(_resource)
    desired_plan = stored_desired_plan
    return dashboard_pricing_path(price_key: desired_plan[:price_key]) if desired_plan&.dig(:price_key).present?

    dashboard_path
  end

  private

  def redirect_signed_in_users
    return unless user_signed_in?

    target = action_name == "pricing" ? dashboard_pricing_path : dashboard_path
    redirect_to target
  end

  def redirect_if_authenticated
    redirect_to dashboard_path if user_signed_in?
  end

  def set_locale
    resolver = LocaleResolver.new(
      request:,
      params:,
      session:,
      user: current_user
    )

    I18n.locale = resolver.resolved_locale
    session[:locale] = I18n.locale
    persist_user_locale(resolver)
  end

  def persist_user_locale(resolver)
    return unless resolver.persist_user_locale?

    updated = current_user.update(preferred_locale: I18n.locale.to_s)
    Rails.logger.warn("Failed to persist locale for user #{current_user.id}") unless updated
  end

  def default_url_options
    I18n.locale == I18n.default_locale ? {} : { locale: I18n.locale }
  end

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:name, :preferred_locale])
    devise_parameter_sanitizer.permit(:account_update, keys: [:name, :preferred_locale])
  end

  def capture_desired_plan
    plan_key = params[:price_key] || params[:plan] || params[:desired_plan]
    return if plan_key.blank?

    cookies.signed[:desired_plan] = {
      value: { price_key: plan_key },
      expires: 1.hour.from_now,
      httponly: true
    }
  end

  def stored_desired_plan
    cookies.signed[:desired_plan]
  end

  def clear_desired_plan
    cookies.delete(:desired_plan)
  end
end
