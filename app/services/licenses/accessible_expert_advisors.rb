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

      eas = ExpertAdvisor.active.includes(:licenses).order(:name)
      license_map = licenses_indexed

      eas.map do |ea|
        license = license_map[ea.id]
        status, accessible, expires_at, license_key = status_for(license)

        Entry.new(
          expert_advisor: ea,
          license: license,
          status: status,
          accessible: accessible,
          expires_at: expires_at,
          license_key: license_key,
          allowed_tiers: Array(ea.allowed_subscription_tiers).presence || Billing::DashboardPlan::TIERS
        )
      end
    end

    private

    attr_reader :user

    def licenses_indexed
      user.licenses.includes(:expert_advisor, :broker_accounts).index_by(&:expert_advisor_id)
    end

    def status_for(license)
      return [:locked, false, nil, nil] unless license
      return [:revoked, false, license.effective_expires_at, nil] if license.revoked?
      return [:expired, false, license.effective_expires_at, nil] if license.expired_by_time?

      key = license.encrypted_key
      if license.trial?
        [:trial, true, license.effective_expires_at, key]
      else
        [:active, true, license.effective_expires_at, key]
      end
    end
  end
end
