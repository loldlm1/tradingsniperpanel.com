module Referrals
  class MarkCompleted
    def initialize(user:, logger: Rails.logger)
      @user = user
      @logger = logger
    end

    def call
      return unless user

      referral = user.referral
      return unless referral

      referral.complete!
    rescue StandardError => e
      logger.warn("[Referrals::MarkCompleted] failed user_id=#{user&.id} error=#{e.class}: #{e.message}")
      nil
    end

    private

    attr_reader :user, :logger
  end
end
