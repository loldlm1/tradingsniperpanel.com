require "set"

module Partners
  class MembershipManager
    def initialize(logger: Rails.logger)
      @logger = logger
    end

    def ensure_profile_for(user)
      return unless user.is_a?(User)
      return unless user.partner?

      PartnerProfile.find_or_create_by!(user:) do |profile|
        profile.discount_percent = profile.discount_percent_or_default
        profile.payout_mode = :once_paid
        profile.started_at = Time.current
      end
    rescue StandardError => e
      logger.warn("[Partners::MembershipManager] failed to ensure profile for user_id=#{user.id}: #{e.class} - #{e.message}")
      nil
    end

    def assign_membership_for(user)
      return unless user.is_a?(User)
      return if user.partner? # Partners own their own branch

      profile, depth = nearest_partner_profile_with_depth(user)
      return unless profile&.active?

      current_membership = PartnerMembership.active.find_by(user: user)
      return current_membership if current_membership&.partner_profile_id == profile.id && current_membership.depth == depth

      PartnerMembership.transaction do
        current_membership&.update!(ended_at: Time.current)

        PartnerMembership.create!(
          partner_profile: profile,
          user: user,
          referral: user.referral,
          depth: depth,
          started_at: Time.current
        )
      end
    rescue StandardError => e
      logger.warn("[Partners::MembershipManager] failed to assign membership for user_id=#{user.id}: #{e.class} - #{e.message}")
      nil
    end

    def reassign_descendants_for(partner_user)
      return unless partner_user.is_a?(User)

      profile = partner_user.partner_profile
      return unless profile&.active?

      queue = partner_user.referrals.includes(:referee).to_a
      until queue.empty?
        referral = queue.shift
        referee = referral&.referee
        next unless referee.is_a?(User)

        unless referee.partner?
          assign_membership_for(referee)
          queue.concat(referee.referrals.includes(:referee)) # continue down branch
        end
      end
    rescue StandardError => e
      logger.warn("[Partners::MembershipManager] failed to reassign descendants for user_id=#{partner_user.id}: #{e.class} - #{e.message}")
      nil
    end

    private

    attr_reader :logger

    def nearest_partner_profile_with_depth(user)
      depth = 0
      current = user
      visited = Set.new

      while current.respond_to?(:referrer) && current.referrer.present?
        referrer = current.referrer
        break if visited.include?(referrer.id)
        visited << referrer.id

        depth += 1
        profile = referrer.partner_profile if referrer.respond_to?(:partner_profile)
        return [profile, depth] if profile&.active?

        current = referrer
      end

      [nil, nil]
    end
  end
end
