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
      return failure(:invalid_payload, :unprocessable_content) if normalized_email.blank? || ea_id.blank? || license_key.blank?

      user = User.find_by("LOWER(email) = ?", normalized_email)
      return failure(:user_not_found, :not_found) unless user

      expert_advisor = ExpertAdvisor.find_by(ea_id: ea_id)
      return failure(:ea_not_found, :not_found) unless expert_advisor

      if Licenses::PrivilegedAccess.full_access?(user)
        return verify_privileged_access(user: user, expert_advisor: expert_advisor, provided_key: license_key)
      end

      license = License.find_by(user:, expert_advisor:)
      return failure(:license_not_found, :not_found) unless license
      return failure(:trial_disabled, :unauthorized) if license.trial? && !expert_advisor.trial_enabled?
      return failure(:expired, :unprocessable_content) if license.revoked? || license.expired_by_time?
      return failure(:invalid_key, :unauthorized) unless key_matches?(
        expected_key: license.encrypted_key,
        provided_key: license_key,
        email: user.email,
        ea_id: expert_advisor.ea_id,
        expires_at: license.key_expires_at
      )

      success(license)
    end

    private

    attr_reader :encoder, :expected_source

    def verify_privileged_access(user:, expert_advisor:, provided_key:)
      license = License.find_by(user:, expert_advisor:) || privileged_access_for(user).ensure_role_license_for(expert_advisor: expert_advisor)
      return failure(:license_not_found, :not_found) unless license

      expected_key, expected_expires_at = privileged_key_material_for(
        user: user,
        expert_advisor: expert_advisor,
        license: license
      )
      return failure(:invalid_key, :unauthorized) unless key_matches?(
        expected_key: expected_key,
        provided_key: provided_key,
        email: user.email,
        ea_id: expert_advisor.ea_id,
        expires_at: expected_expires_at
      )

      success(license, trial: false, expires_at: expected_expires_at)
    end

    def privileged_key_material_for(user:, expert_advisor:, license:)
      if license.persisted? && !license.revoked? && !license.expired_by_time? && license.encrypted_key.present?
        return [license.encrypted_key, license.key_expires_at]
      end

      generated_key = Licenses::PrivilegedAccess.generated_key_for(
        user: user,
        expert_advisor: expert_advisor,
        encoder: encoder
      )

      [generated_key, License::LIFETIME_EXPIRES_AT]
    end

    def privileged_access_for(user)
      @privileged_access_by_user_id ||= {}
      @privileged_access_by_user_id[user.id] ||= Licenses::PrivilegedAccess.new(user: user, encoder: encoder)
    end

    def key_matches?(expected_key:, provided_key:, email:, ea_id:, expires_at:)
      return false unless secure_compare(expected_key, provided_key)

      encoder.valid_key?(
        license_key: provided_key,
        email: email,
        ea_id: ea_id,
        expires_at: expires_at
      )
    end

    def valid_source?(source)
      source.to_s == expected_source.to_s
    end

    def success(license, trial: license.trial?, expires_at: license.key_expires_at)
      Result.new(
        ok: true,
        code: :ok,
        license: license,
        expires_at: expires_at,
        plan_interval: license.plan_interval,
        trial: trial
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
