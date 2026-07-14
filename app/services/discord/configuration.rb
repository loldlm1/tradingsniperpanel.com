require "uri"

module Discord
  def self.configuration
    Rails.application.config.x.discord
  end

  def self.enabled?
    configuration.enabled?
  end

  class Configuration
    PRODUCTION_REDIRECT_URI = "https://tradingsniperpanel.com/discord/callback".freeze
    REQUIRED_ENV_KEYS = {
      client_id: "DISCORD_CLIENT_ID",
      client_secret: "DISCORD_CLIENT_SECRET",
      bot_token: "DISCORD_BOT_TOKEN",
      guild_id: "DISCORD_GUILD_ID",
      vip_role_id: "DISCORD_VIP_ROLE_ID",
      redirect_uri: "DISCORD_REDIRECT_URI",
      support_url: "SUPPORT_DISCORD_URL"
    }.freeze

    attr_reader(*REQUIRED_ENV_KEYS.keys)

    def self.from_env(env, environment: Rails.env)
      enabled = ActiveModel::Type::Boolean.new.cast(env.fetch("DISCORD_INTEGRATION_ENABLED", "false"))
      values = REQUIRED_ENV_KEYS.transform_values { |key| env[key] }

      new(enabled: enabled, environment: environment, **values).tap do |configuration|
        configuration.validate! if configuration.enabled?
      end
    end

    def initialize(enabled:, environment:, **values)
      @enabled = enabled
      @environment = environment.to_s
      REQUIRED_ENV_KEYS.each_key do |attribute|
        instance_variable_set("@#{attribute}", normalize(values[attribute]))
      end
      freeze
    end

    def enabled?
      @enabled
    end

    def validate!
      missing = REQUIRED_ENV_KEYS.filter_map do |attribute, env_key|
        env_key if public_send(attribute).blank?
      end
      if missing.any?
        raise ConfigurationError.new(
          "Discord integration is enabled but required configuration is missing: #{missing.join(', ')}",
          code: :missing_configuration
        )
      end

      validate_uri!(redirect_uri, env_key: "DISCORD_REDIRECT_URI")
      validate_uri!(support_url, env_key: "SUPPORT_DISCORD_URL")
      validate_production_redirect!
      self
    end

    private

    attr_reader :environment

    def normalize(value)
      value.to_s.strip.presence&.freeze
    end

    def validate_uri!(value, env_key:)
      uri = URI.parse(value)
      return if uri.is_a?(URI::HTTP) && uri.host.present?

      raise URI::InvalidURIError
    rescue URI::InvalidURIError
      raise ConfigurationError.new(
        "Discord integration has an invalid #{env_key}",
        code: :invalid_configuration
      )
    end

    def validate_production_redirect!
      return unless environment == "production"
      return if redirect_uri == PRODUCTION_REDIRECT_URI

      raise ConfigurationError.new(
        "Discord integration has an invalid production DISCORD_REDIRECT_URI",
        code: :invalid_configuration
      )
    end
  end
end
