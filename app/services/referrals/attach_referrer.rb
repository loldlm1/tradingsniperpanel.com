module Referrals
  class AttachReferrer
    def initialize(user:, code:, logger: Rails.logger)
      @user = user
      @code = code.to_s.strip.upcase
      @logger = logger
    end

    def call
      return if user.blank?
      return if code.blank?
      return handle_existing_referrer if user.referrer.present?
      return unless partner_profile

      Refer.refer(code:, referee: user)
      user.reload
      Partners::MembershipManager.new.assign_membership_for(user)
    rescue StandardError => e
      logger.warn(
        "[Referrals::AttachReferrer] failed user_id=#{user&.id} code=#{code} error=#{e.class}: #{e.message}"
      )
      nil
    end

    private

    attr_reader :user, :code, :logger

    def handle_existing_referrer
      current_referrer = user.referrer
      return unless current_referrer.is_a?(User)
      return unless current_referrer == partner_profile&.user

      Partners::MembershipManager.new.assign_membership_for(user)
    end

    def partner_profile
      @partner_profile ||= PartnerProfile.active.find_by(referral_code: code)
    end
  end
end
