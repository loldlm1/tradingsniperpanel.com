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

      coupon_id = Billing::ReferralCoupon.new(percent: discount_percent).coupon_id
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

    def discount_percent
      (percent.presence || ENV.fetch("REFER_DEFAULT_DISCOUNT_PERCENT", "0")).to_i
    end

    def referral_metadata
      referral = user.referral
      return {} unless referral

      {
        "referral_code" => referral.referral_code&.code.to_s.presence,
        "referrer_id" => user.referrer&.id&.to_s,
        "referrer_type" => user.referrer&.class&.name,
        "referral_discount_percent" => discount_percent.to_s
      }.compact
    end

    def merge_metadata!(params, metadata)
      return if metadata.blank?

      params[:metadata] = (params[:metadata] || {}).merge(metadata)
      params[:subscription_data] ||= {}
      params[:subscription_data][:metadata] = (params[:subscription_data][:metadata] || {}).merge(metadata)
    end
  end
end
