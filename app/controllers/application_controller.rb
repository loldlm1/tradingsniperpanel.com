class ApplicationController < ActionController::Base
  set_referral_cookie
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :set_locale
  before_action :configure_permitted_parameters, if: :devise_controller?

  private

  def set_locale
    I18n.locale = (
      locale_from_params ||
      session[:locale] ||
      current_user&.preferred_locale_code&.to_s ||
      geoip_locale ||
      accept_language_locale ||
      I18n.default_locale
    )

    session[:locale] = I18n.locale
    persist_user_locale
  end

  def locale_from_params
    return unless params[:locale].present?

    locale = params[:locale].to_s
    locale if I18n.available_locales.map(&:to_s).include?(locale)
  end

  def accept_language_locale
    header = request.env["HTTP_ACCEPT_LANGUAGE"]
    return if header.blank?

    header.split(",").map { |lang| lang.split(";").first.to_s.downcase }.find do |lang|
      I18n.available_locales.map(&:to_s).include?(lang)
    end
  end

  def geoip_locale
    return if request.remote_ip.blank? || request.remote_ip.start_with?("127.", "10.", "192.168.", "172.16.", "::1")

    path = ENV.fetch("MAXMIND_DB_PATH", Rails.root.join("maxmind/GeoLite2-City.mmdb").to_s)
    return unless File.exist?(path)

    @maxmind_db ||= MaxMindDB.new(path)
    result = @maxmind_db.lookup(request.remote_ip)
    country = result&.country&.iso_code

    return "es" if %w[ES MX AR CO PE CL VE EC GT DO HN SV NI CR UY PA PR BO CU PY].include?(country)

    nil
  rescue StandardError => e
    Rails.logger.debug { "GeoIP lookup failed: #{e.message}" }
    nil
  end

  def persist_user_locale
    return unless current_user&.preferred_locale != I18n.locale.to_s

    current_user.update_column(:preferred_locale, I18n.locale.to_s)
  end

  def default_url_options
    I18n.locale == I18n.default_locale ? {} : { locale: I18n.locale }
  end

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:name, :preferred_locale])
    devise_parameter_sanitizer.permit(:account_update, keys: [:name, :preferred_locale])
  end
end
