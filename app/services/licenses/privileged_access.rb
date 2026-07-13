module Licenses
  class PrivilegedAccess
    ROLE_LICENSE_SOURCE = "role_access".freeze

    def self.full_access?(user)
      Access::PrivilegedRolePolicy.full_access?(user)
    end

    def self.generated_key_for(user:, expert_advisor:, encoder: LicenseKeyEncoder.new, token_version: 1)
      return nil unless user.is_a?(User)
      return nil unless expert_advisor.is_a?(ExpertAdvisor)
      return nil unless encoder.configured?

      encoder.generate(
        email: user.email,
        ea_id: expert_advisor.ea_id,
        expires_at: License::LIFETIME_EXPIRES_AT,
        token_version: token_version
      )
    end

    def initialize(user:, encoder: LicenseKeyEncoder.new, logger: Rails.logger, now: Time.current)
      @user = user
      @encoder = encoder
      @logger = logger
      @now = now
    end

    def sync_all
      return unless user.is_a?(User)

      if privileged_full_access?
        provision_role_licenses
      else
        revoke_role_licenses
      end
    end

    def ensure_role_license_for(expert_advisor:)
      return unless user.is_a?(User)
      return unless expert_advisor.is_a?(ExpertAdvisor)
      return unless privileged_full_access?
      return unless encoder.configured?

      license = License.find_or_initialize_by(user: user, expert_advisor: expert_advisor)

      license.with_lock do
        return license if preserve_existing_license?(license)

        apply_role_license_attributes(license: license, expert_advisor: expert_advisor)
        license.save!
      end

      license
    end

    private

    attr_reader :user, :encoder, :logger, :now

    def privileged_full_access?
      self.class.full_access?(user)
    end

    def provision_role_licenses
      unless encoder.configured?
        logger.warn("[Licenses::PrivilegedAccess] skipped provisioning: license keys not configured user_id=#{user.id}")
        return
      end

      ExpertAdvisor.active.find_each do |expert_advisor|
        ensure_role_license_for(expert_advisor: expert_advisor)
      end
    end

    def revoke_role_licenses
      user.licenses.where(source: ROLE_LICENSE_SOURCE).find_each do |license|
        next if license.revoked? && license.expires_at.present? && license.expires_at <= now

        license.update!(
          status: "revoked",
          trial_ends_at: nil,
          expires_at: now,
          last_synced_at: now
        )
      end
    end

    def preserve_existing_license?(license)
      license.persisted? && license.source.to_s != ROLE_LICENSE_SOURCE
    end

    def apply_role_license_attributes(license:, expert_advisor:)
      encrypted_key = self.class.generated_key_for(
        user: user,
        expert_advisor: expert_advisor,
        encoder: encoder,
        token_version: license.token_version
      )

      license.status = "active"
      license.access_source = "one_time"
      license.plan_interval = nil
      license.trial_ends_at = nil
      license.expires_at = nil
      license.source = ROLE_LICENSE_SOURCE
      license.last_synced_at = now
      license.encrypted_key = encrypted_key
    end
  end
end
