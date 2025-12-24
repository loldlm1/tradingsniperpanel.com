module Licenses
  class ExpireLicenses
    def initialize(now: Time.current, logger: Rails.logger)
      @now = now
      @logger = logger
    end

    def call
      expired_trials = expire_trials
      expired_actives = expire_actives
      logger.info("[Licenses::ExpireLicenses] expired_trials=#{expired_trials} expired_actives=#{expired_actives}")
    end

    private

    attr_reader :now, :logger

    def expire_trials
      expire_scope(License.trial.where("trial_ends_at <= ?", now))
    end

    def expire_actives
      expire_scope(License.active.where("expires_at <= ?", now))
    end

    def expire_scope(scope)
      scope.update_all(status: "expired", last_synced_at: now, updated_at: now)
    end
  end
end
