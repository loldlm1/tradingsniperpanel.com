module Partners
  class MembershipManager
    DIRECT_REFERRAL_DEPTH = 1

    def initialize(logger: Rails.logger)
      @logger = logger
    end

    def ensure_profile_for(user)
      return unless user.is_a?(User)

      PartnerProfile.find_or_create_by!(user:) do |profile|
        profile.discount_percent = profile.discount_percent_or_default
        profile.commission_percent = profile.commission_percent_or_default
        profile.payout_mode = :once_paid
        profile.started_at = Time.current
      end
    rescue StandardError => e
      logger.warn("[Partners::MembershipManager] failed to ensure profile for user_id=#{user.id}: #{e.class} - #{e.message}")
      nil
    end

    def assign_membership_for(user)
      return unless user.is_a?(User)

      profile = direct_partner_profile_for(user)
      current_membership = PartnerMembership.active.find_by(user: user)

      unless profile
        current_membership&.update!(ended_at: Time.current)
        return nil
      end

      return current_membership if current_membership&.partner_profile_id == profile.id && current_membership.depth == DIRECT_REFERRAL_DEPTH

      PartnerMembership.transaction do
        current_membership&.update!(ended_at: Time.current)

        PartnerMembership.create!(
          partner_profile: profile,
          user: user,
          referral: user.referral,
          depth: DIRECT_REFERRAL_DEPTH,
          started_at: Time.current
        )
      end
    rescue StandardError => e
      logger.warn("[Partners::MembershipManager] failed to assign membership for user_id=#{user.id}: #{e.class} - #{e.message}")
      nil
    end

    def reassign_descendants_for(partner_user)
      return unless partner_user.is_a?(User)

      partner_user.referrals.includes(:referee).find_each do |referral|
        referee = referral.referee
        next unless referee.is_a?(User)

        assign_membership_for(referee)
      end
    rescue StandardError => e
      logger.warn("[Partners::MembershipManager] failed to reassign direct referrals for user_id=#{partner_user.id}: #{e.class} - #{e.message}")
      nil
    end

    private

    attr_reader :logger

    def direct_partner_profile_for(user)
      referrer = user.referrer
      return unless referrer.is_a?(User)

      profile = referrer.partner_profile
      return unless profile&.active?

      profile
    end
  end
end
