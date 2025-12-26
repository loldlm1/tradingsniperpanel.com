class ApplicationController < ActionController::Base
  set_referral_cookie
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :set_locale
  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :capture_desired_plan, if: -> { request.format.html? }
  before_action :ensure_terms_accepted, if: :user_signed_in?
  before_action :set_accessible_expert_advisors, if: :user_signed_in?

  def after_sign_in_path_for(_resource)
    desired_plan = stored_desired_plan
    if desired_plan&.dig(:price_key).present?
      return dashboard_plans_path(price_key: desired_plan[:price_key])
    elsif desired_plan&.dig(:product_id).present?
      return dashboard_plans_path(product_id: desired_plan[:product_id])
    end

    dashboard_path
  end

  private

  def redirect_signed_in_users
    return unless user_signed_in?

    target = action_name == "pricing" ? dashboard_plans_path : dashboard_path
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

  def current_user
    user = begin
      super
    rescue NoMethodError
      nil
    end
    return user if user.is_a?(User) || user.nil?

    if user.is_a?(Hash)
      User.find_by(id: user["id"] || user[:id]) || user
    else
      user
    end
  end

  def default_url_options
    I18n.locale == I18n.default_locale ? {} : { locale: I18n.locale }
  end

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:name, :preferred_locale, :terms_of_service])
    devise_parameter_sanitizer.permit(:account_update, keys: [:name, :preferred_locale])
  end

  def capture_desired_plan
    plan_key = params[:price_key] || params[:plan] || params[:desired_plan]
    product_id = params[:product_id]
    return if plan_key.blank? && product_id.blank?

    cookies.signed[:desired_plan] = {
      value: { price_key: plan_key, product_id: product_id },
      expires: 1.hour.from_now,
      httponly: true
    }
  end

  def stored_desired_plan
    plan = cookies.signed[:desired_plan]
    plan.respond_to?(:with_indifferent_access) ? plan.with_indifferent_access : plan
  end

  def clear_desired_plan
    cookies.delete(:desired_plan)
  end

  def set_accessible_expert_advisors
    @accessible_eas ||= Licenses::AccessibleExpertAdvisors.new(user: current_user).call
  end

  def ensure_terms_accepted
    return unless current_user.respond_to?(:terms_accepted_at)
    return if current_user.terms_accepted_at.present?
    return unless requires_terms_acceptance?

    redirect_to new_terms_acceptance_path, alert: t("terms_acceptance.required")
  end

  def requires_terms_acceptance?
    return false if devise_controller?
    return false if controller_path == "terms_acceptances"
    return false if controller_path == "legal"
    return false unless request.format.html?

    request.path.include?("/dashboard")
  end
end
