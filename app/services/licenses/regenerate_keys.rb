module Licenses
  class RegenerateKeys
    def initialize(encoder: LicenseKeyEncoder.new, logger: Rails.logger)
      @encoder = encoder
      @logger = logger
    end

    def call
      unless encoder.configured?
        logger.warn("[Licenses::RegenerateKeys] skipped: license keys not configured")
        return
      end

      updated = 0
      skipped = 0

      License.active_or_trial.includes(:user, :expert_advisor).find_each do |license|
        expires_at = license.effective_expires_at
        if expires_at.blank?
          skipped += 1
          logger.warn("[Licenses::RegenerateKeys] skipped license_id=#{license.id} missing expires_at")
          next
        end

        license.update!(
          encrypted_key: encoder.generate(
            email: license.user.email,
            ea_id: license.expert_advisor.ea_id,
            expires_at: expires_at
          ),
          last_synced_at: Time.current
        )
        updated += 1
      rescue StandardError => e
        logger.error("[Licenses::RegenerateKeys] failed license_id=#{license.id}: #{e.class} - #{e.message}")
      end

      logger.info("[Licenses::RegenerateKeys] updated=#{updated} skipped=#{skipped}")
    end

    private

    attr_reader :encoder, :logger
  end
end
