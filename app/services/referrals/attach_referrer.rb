module Referrals
  class AttachReferrer
    def initialize(user:, code:, logger: Rails.logger)
      @user = user
      @code = code
      @logger = logger
    end

    def call
      return if user.blank?
      return if code.blank?

      Refer.refer(code:, referee: user)
      user.reload
      user.ensure_referral_code_if_referred!
      Partners::MembershipManager.new.assign_membership_for(user)
    rescue StandardError => e
      logger.warn(
        "[Referrals::AttachReferrer] failed user_id=#{user&.id} code=#{code} error=#{e.class}: #{e.message}"
      )
      nil
    end

    private

    attr_reader :user, :code, :logger
  end
end
