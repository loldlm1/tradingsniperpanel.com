module Licenses
  class AccessibleExpertAdvisors
    Entry = Struct.new(
      :expert_advisor,
      :license,
      :status,
      :accessible,
      :expires_at,
      :license_key,
      :allowed_tiers,
      keyword_init: true
    )

    def initialize(user:)
      @user = user
    end

    def call
      return [] unless user
      return [] unless user.respond_to?(:licenses)

      eas = ExpertAdvisor.active.includes(
        :licenses,
        :billing_plan_entitlements,
        :billing_plans,
        :expert_advisor_bundles,
        :tags,
        ea_files_attachment: :blob
      )
                          .ordered_by_rank
      license_map = licenses_indexed
      privileged_full_access = Access::PrivilegedRolePolicy.full_access?(user)

      eas.map do |ea|
        license = license_map[ea.id]
        status, accessible, expires_at, license_key = status_for(
          license,
          expert_advisor: ea,
          privileged_full_access: privileged_full_access
        )

        Entry.new(
          expert_advisor: ea,
          license: license,
          status: status,
          accessible: accessible,
          expires_at: expires_at,
          license_key: license_key,
          allowed_tiers: allowed_tiers_for(ea)
        )
      end
    end

    private

    attr_reader :user

    def licenses_indexed
      user.licenses.includes(:expert_advisor, :broker_accounts).index_by(&:expert_advisor_id)
    end

    def status_for(license, expert_advisor:, privileged_full_access:)
      if privileged_full_access
        key = privileged_license_key_for(license: license, expert_advisor: expert_advisor)
        return [:active, true, License::LIFETIME_EXPIRES_AT, key]
      end

      return [:locked, false, nil, nil] unless license
      return [:revoked, false, license.effective_expires_at, nil] if license.revoked?
      return [:expired, false, license.effective_expires_at, nil] if license.expired_by_time?

      key = license.encrypted_key
      if license.trial?
        [:trial, true, license.trial_ends_at || license.key_expires_at, key]
      else
        [:active, true, license.key_expires_at, key]
      end
    end

    def privileged_license_key_for(license:, expert_advisor:)
      if license.present? && !license.revoked? && !license.expired_by_time? && license.encrypted_key.present?
        return license.encrypted_key
      end

      Licenses::PrivilegedAccess.generated_key_for(user: user, expert_advisor: expert_advisor)
    end

    def allowed_tiers_for(expert_advisor)
      tiers = expert_advisor.subscription_tiers
      return tiers if tiers.present?

      BillingPlan.subscription_tiers.map(&:tier)
    end
  end
end
