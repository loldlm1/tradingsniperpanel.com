module Licenses
  class TrialProvisioner
    TRIAL_PERIOD = 3.days

    def initialize(user:, encoder: LicenseKeyEncoder.new, now: Time.current)
      @user = user
      @encoder = encoder
      @now = now
    end

    def call
      return unless user

      ExpertAdvisor.active.where(trial_enabled: true).find_each do |expert_advisor|
        provision_for(expert_advisor)
      end
    end

    private

    attr_reader :user, :encoder, :now

    def provision_for(expert_advisor)
      license = License.find_or_initialize_by(user:, expert_advisor:)
      return if license.persisted?

      license.encrypted_key = encoder.generate(email: user.email, ea_id: expert_advisor.ea_id)
      license.status = "trial"
      license.trial_ends_at = now + TRIAL_PERIOD
      license.plan_interval ||= nil
      license.source = "trial"
      license.last_synced_at = now
      license.save!
    end
  end
end
