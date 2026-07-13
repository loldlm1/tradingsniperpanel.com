module Licenses
  class RevokeRoleAccess
    ROLE_LICENSE_SOURCE = "role_access".freeze

    Result = Struct.new(:license_ids, :revoked_at, keyword_init: true) do
      def count
        license_ids.size
      end
    end

    def initialize(now: Time.current)
      @now = now
    end

    def call
      revoked_ids = License.transaction do
        role_access_scope.reorder(:id).lock.filter_map do |license|
          next unless revocation_needed?(license)

          license.update!(
            status: "revoked",
            trial_ends_at: nil,
            expires_at: now,
            last_synced_at: now
          )
          license.id
        end
      end

      Result.new(license_ids: revoked_ids.freeze, revoked_at: now)
    end

    private

    attr_reader :now

    def role_access_scope
      License.where(source: ROLE_LICENSE_SOURCE)
    end

    def revocation_needed?(license)
      !license.revoked? || license.trial_ends_at.present? || license.expires_at.blank? || license.expires_at > now
    end
  end
end
