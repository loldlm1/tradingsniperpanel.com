module Referrals
  class RedemptionState
    def initialize(user:)
      @user = user
    end

    def referral
      @referral ||= user.is_a?(User) ? user.referral : nil
    end

    def referrer
      @referrer ||= user.is_a?(User) ? user.referrer : nil
    end

    def referred?
      referral.present? && referrer.present?
    end

    def redeemable?
      referred? && completed_at.blank?
    end

    def completed_at
      referral&.completed_at
    end

    def completed?
      completed_at.present?
    end

    def owned_by?(referrer_user)
      referred? && referrer == referrer_user
    end

    def completed_after_or_at?(timestamp)
      return false if completed_at.blank? || timestamp.blank?

      completed_at >= timestamp
    end

    private

    attr_reader :user
  end
end
