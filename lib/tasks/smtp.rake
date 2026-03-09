require "net/smtp"

namespace :smtp do
  def env_smtp_settings
    {
      address: ENV["SMTP_ADDRESS"],
      port: ENV["SMTP_PORT"],
      domain: ENV["SMTP_DOMAIN"],
      user_name: ENV["SMTP_USERNAME"],
      password: ENV["SMTP_PASSWORD"],
      authentication: ENV["SMTP_AUTHENTICATION"],
      enable_starttls_auto: ENV["SMTP_ENABLE_STARTTLS_AUTO"],
      open_timeout: ENV["SMTP_OPEN_TIMEOUT"],
      read_timeout: ENV["SMTP_READ_TIMEOUT"]
    }.transform_values { |value| value.is_a?(String) ? value.strip.presence : value }.compact
  end

  def effective_smtp_settings
    env_smtp_settings.merge(Rails.application.config.action_mailer.smtp_settings.to_h.symbolize_keys.compact)
  end

  def boolean(value, default:)
    return default if value.nil?

    ActiveModel::Type::Boolean.new.cast(value)
  end

  def normalized_smtp_settings
    raw = effective_smtp_settings

    {
      address: raw[:address],
      port: raw[:port].presence || 587,
      domain: raw[:domain].presence || ENV.fetch("APP_HOST", "localhost"),
      user_name: raw[:user_name],
      password: raw[:password],
      authentication: raw[:authentication].presence || "login",
      enable_starttls_auto: boolean(raw[:enable_starttls_auto], default: true),
      open_timeout: raw[:open_timeout].presence || 5,
      read_timeout: raw[:read_timeout].presence || 10
    }
  end

  def apply_runtime_smtp_settings!(settings)
    ActionMailer::Base.delivery_method = :smtp
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.raise_delivery_errors = true
    ActionMailer::Base.smtp_settings = {
      address: settings.fetch(:address),
      port: settings.fetch(:port).to_i,
      domain: settings.fetch(:domain),
      user_name: settings.fetch(:user_name),
      password: settings.fetch(:password),
      authentication: settings.fetch(:authentication).to_sym,
      enable_starttls_auto: settings.fetch(:enable_starttls_auto),
      open_timeout: settings.fetch(:open_timeout).to_i,
      read_timeout: settings.fetch(:read_timeout).to_i
    }
  end

  desc "Check SMTP connectivity/authentication using current Action Mailer settings"
  task check: :environment do
    settings = normalized_smtp_settings
    required_keys = %i[address port user_name password]
    missing_keys = required_keys.select { |key| settings[key].blank? }

    if missing_keys.any?
      abort("smtp:check failed: missing SMTP settings: #{missing_keys.join(', ')}. Ensure SMTP env vars are loaded (for example via `direnv allow` or `source .envrc`).")
    end

    domain = settings[:domain].presence || ENV.fetch("APP_HOST", "localhost")
    authentication = settings[:authentication].presence || :login
    open_timeout = settings[:open_timeout].presence || 5
    read_timeout = settings[:read_timeout].presence || 10

    puts "[smtp:check] address=#{settings[:address]} port=#{settings[:port]} user=#{settings[:user_name]} auth=#{authentication} domain=#{domain}"
    puts "[smtp:check] timeouts open=#{open_timeout}s read=#{read_timeout}s"

    smtp = Net::SMTP.new(settings[:address], settings[:port])
    smtp.open_timeout = open_timeout.to_i
    smtp.read_timeout = read_timeout.to_i
    smtp.enable_starttls_auto if ActiveModel::Type::Boolean.new.cast(settings[:enable_starttls_auto])

    smtp.start(domain, settings[:user_name], settings[:password], authentication.to_sym) do
      puts "[smtp:check] connection/authentication succeeded"
    end
  rescue StandardError => e
    warn "[smtp:check] FAILED #{e.class}: #{e.message}"
    exit(1)
  end

  desc "Send a test email using SMTP (usage: TO=you@example.com [SUBJECT='...'] bundle exec rails smtp:send_test)"
  task send_test: :environment do
    to = ENV["TO"].to_s.strip
    abort("smtp:send_test failed: TO is required (example: TO=you@example.com bundle exec rails smtp:send_test)") if to.blank?
    settings = normalized_smtp_settings
    required_keys = %i[address port user_name password]
    missing_keys = required_keys.select { |key| settings[key].blank? }
    abort("smtp:send_test failed: missing SMTP settings: #{missing_keys.join(', ')}") if missing_keys.any?

    apply_runtime_smtp_settings!(settings)

    subject_brand = Rails.configuration.x.branding.email_subject_brand
    subject = ENV.fetch("SUBJECT", "#{subject_brand} SMTP delivery check")
    body = <<~BODY
      SMTP test email sent at #{Time.current.utc.iso8601}
      Environment: #{Rails.env}
      APP_HOST: #{ENV.fetch("APP_HOST", "n/a")}
      Reply-To: #{ApplicationMailer.email_reply_to_address}
    BODY

    ActionMailer::Base.mail(
      from: ApplicationMailer.email_from_address,
      reply_to: ApplicationMailer.email_reply_to_address,
      to: to,
      subject: subject,
      body: body
    ).deliver_now

    puts "[smtp:send_test] delivered to #{to}"
  rescue StandardError => e
    warn "[smtp:send_test] FAILED #{e.class}: #{e.message}"
    exit(1)
  end
end
