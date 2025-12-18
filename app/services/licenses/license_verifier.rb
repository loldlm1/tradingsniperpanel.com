module Licenses
  class LicenseVerifier
    Result = Struct.new(:ok, :code, :error, :license, :expires_at, :plan_interval, :trial, keyword_init: true) do
      def ok?
        !!self[:ok]
      end
    end

    def initialize(encoder: LicenseKeyEncoder.new, expected_source: ENV.fetch("EA_LICENSE_SOURCE_ID", "trading_sniper_ea"))
      @encoder = encoder
      @expected_source = expected_source
    end

    def call(source:, email:, ea_id:, license_key:)
      normalized_email = email.to_s.strip.downcase

      return failure(:invalid_source, :unauthorized) unless valid_source?(source)
      return failure(:invalid_payload, :unprocessable_entity) if normalized_email.blank? || ea_id.blank? || license_key.blank?

      user = User.find_by("LOWER(email) = ?", normalized_email)
      return failure(:user_not_found, :not_found) unless user

      expert_advisor = ExpertAdvisor.find_by(ea_id: ea_id)
      return failure(:ea_not_found, :not_found) unless expert_advisor

      license = License.find_by(user:, expert_advisor:)
      return failure(:license_not_found, :not_found) unless license
      return failure(:trial_disabled, :unauthorized) if license.trial? && !expert_advisor.trial_enabled?
      return failure(:expired, :unprocessable_entity) if license.revoked? || license.expired_by_time?
      return failure(:invalid_key, :unauthorized) unless secure_compare(license.encrypted_key, license_key)
      return failure(:invalid_key, :unauthorized) unless encoder.valid_key?(license_key:, email: user.email, ea_id: expert_advisor.ea_id)

      success(license)
    end

    private

    attr_reader :encoder, :expected_source

    def valid_source?(source)
      source.to_s == expected_source.to_s
    end

    def success(license)
      Result.new(
        ok: true,
        code: :ok,
        license: license,
        expires_at: license.effective_expires_at,
        plan_interval: license.plan_interval,
        trial: license.trial?
      )
    end

    def failure(error, code)
      Result.new(ok: false, error:, code:)
    end

    def secure_compare(a, b)
      return false if a.blank? || b.blank?

      ActiveSupport::SecurityUtils.secure_compare(a.to_s, b.to_s)
    rescue StandardError
      false
    end
  end
end
