module Billing
  class ApplyReferralDiscount
    def initialize(user:, checkout_params:, percent: nil, logger: Rails.logger)
      @user = user
      @checkout_params = checkout_params
      @percent = percent
      @logger = logger
    end

    def call
      return checkout_params unless eligible?

      partner_profile, partner_percent = resolver
      return checkout_params unless partner_profile

      coupon_id = Partners::ReferralCoupon.new(partner_profile: partner_profile, percent: partner_percent).coupon_id
      return checkout_params if coupon_id.blank?

      with_discount = checkout_params.deep_dup
      with_discount.delete(:allow_promotion_codes) # Stripe disallows allow_promotion_codes with discounts
      with_discount[:discounts] = [{ coupon: coupon_id }]
      merge_metadata!(with_discount, referral_metadata)
      with_discount
    rescue StandardError => e
      logger.warn(
        "[Billing::ApplyReferralDiscount] failed user_id=#{user&.id}: #{e.class} - #{e.message}\n#{e.backtrace&.first(5)&.join("\n")}"
      )
      checkout_params
    end

    private

    attr_reader :user, :checkout_params, :percent, :logger

    def eligible?
      user.is_a?(User) && user.referrer.present?
    end

    def resolver
      profile, default_percent = Partners::DiscountResolver.new(user: user).call
      return [nil, nil] unless profile

      resolved_percent = (percent.presence || default_percent).to_i
      return [nil, nil] unless resolved_percent.positive?

      [profile, resolved_percent]
    end

    def referral_metadata
      referral = user.referral
      return {} unless referral

      {
        "referral_code" => referral.referral_code&.code.to_s.presence,
        "referrer_id" => user.referrer&.id&.to_s,
        "referrer_type" => user.referrer&.class&.name,
        "referral_discount_percent" => resolver.last.to_s,
        "partner_profile_id" => partner_membership&.partner_profile_id&.to_s,
        "partner_membership_id" => partner_membership&.id&.to_s,
        "partner_payout_mode" => partner_membership&.partner_profile&.payout_mode
      }.compact
    end

    def partner_membership
      @partner_membership ||= PartnerMembership.active.find_by(user: user)
    end

    def merge_metadata!(params, metadata)
      return if metadata.blank?

      params[:metadata] = (params[:metadata] || {}).merge(metadata)
      params[:subscription_data] ||= {}
      params[:subscription_data][:metadata] = (params[:subscription_data][:metadata] || {}).merge(metadata)
    end
  end
end
