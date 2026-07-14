require "digest"
require "securerandom"

module Discord
  class OauthState
    class InvalidState < StandardError; end
    class ExpiredState < InvalidState; end

    SESSION_KEY = "discord_oauth_state".freeze
    RETURN_TARGET = "dashboard_discord_connection".freeze
    TTL = 10.minutes
    Payload = Data.define(:locale, :return_target)

    def initialize(session:, clock: Time, random: SecureRandom)
      @session = session
      @clock = clock
      @random = random
    end

    def issue(locale: I18n.locale, return_target: RETURN_TARGET)
      normalized_locale = locale.to_s
      raise ArgumentError, "unsupported locale" unless normalized_locale.in?(I18n.available_locales.map(&:to_s))
      raise ArgumentError, "unsupported return target" unless return_target == RETURN_TARGET

      raw_state = random.urlsafe_base64(32)
      session[SESSION_KEY] = {
        "digest" => digest(raw_state),
        "expires_at" => (clock.now + TTL).to_i,
        "locale" => normalized_locale,
        "return_target" => RETURN_TARGET
      }
      raw_state
    end

    def consume(candidate)
      stored = session.delete(SESSION_KEY)
      raise InvalidState unless valid_record?(stored)
      raise ExpiredState if stored.fetch("expires_at") <= clock.now.to_i

      candidate_digest = digest(candidate.to_s)
      raise InvalidState unless ActiveSupport::SecurityUtils.secure_compare(stored.fetch("digest"), candidate_digest)

      Payload.new(
        locale: stored.fetch("locale"),
        return_target: stored.fetch("return_target")
      )
    end

    private

    attr_reader :session, :clock, :random

    def digest(value)
      Digest::SHA256.hexdigest(value)
    end

    def valid_record?(stored)
      stored.is_a?(Hash) &&
        stored["digest"].to_s.length == 64 &&
        stored["expires_at"].is_a?(Integer) &&
        stored["locale"].to_s.in?(I18n.available_locales.map(&:to_s)) &&
        stored["return_target"] == RETURN_TARGET
    end
  end
end
