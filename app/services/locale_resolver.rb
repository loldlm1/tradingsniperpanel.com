class LocaleResolver
  PRIVATE_IP_PREFIXES = ["127.", "10.", "192.168.", "172.16.", "::1"].freeze
  SPANISH_COUNTRIES = %w[ES MX AR CO PE CL VE EC GT DO HN SV NI CR UY PA PR BO CU PY].freeze

  attr_reader :params, :session, :request, :user, :logger

  def initialize(params:, session:, request:, user:, logger: Rails.logger)
    @params = params
    @session = session
    @request = request
    @user = user
    @logger = logger
  end

  def resolved_locale
    @resolved_locale ||= begin
      locale_from_params ||
        session_locale ||
        user_locale ||
        geoip_locale ||
        accept_language_locale ||
        default_locale
    end
  end

  def persist_user_locale?
    user_responds_to_locale? && user.preferred_locale.to_s != resolved_locale.to_s
  end

  private

  def available_locale?(locale)
    locale.present? && I18n.available_locales.map(&:to_s).include?(locale.to_s)
  end

  def locale_from_params
    value = params[:locale].to_s if params[:locale].present?
    value if available_locale?(value)
  end

  def session_locale
    value = session[:locale].to_s if session[:locale].present?
    value if available_locale?(value)
  end

  def user_locale
    return unless user_responds_to_locale? && user.preferred_locale.present?

    value = user.preferred_locale.to_s
    value if available_locale?(value)
  end

  def user_responds_to_locale?
    user.present? && user.respond_to?(:preferred_locale)
  end

  def accept_language_locale
    header = request.env["HTTP_ACCEPT_LANGUAGE"]
    return if header.blank?

    header.split(",").each do |language|
      code = language.split(";").first.to_s.downcase
      return code if available_locale?(code)

      base = code.split("-").first
      return base if available_locale?(base)
    end

    nil
  end

  def geoip_locale
    ip = request.remote_ip
    return if ip.blank? || PRIVATE_IP_PREFIXES.any? { |prefix| ip.start_with?(prefix) }

    path = ENV.fetch("MAXMIND_DB_PATH", Rails.root.join("maxmind/GeoLite2-City.mmdb").to_s)
    return unless File.exist?(path)

    @maxmind_db ||= MaxMindDB.new(path)
    result = @maxmind_db.lookup(ip)
    country = result&.country&.iso_code

    return "es" if country.present? && SPANISH_COUNTRIES.include?(country)
  rescue StandardError => e
    logger.debug { "GeoIP lookup failed: #{e.message}" }
    nil
  end

  def default_locale
    I18n.default_locale.to_s
  end
end
