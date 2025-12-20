module Billing
  class ReferralCoupon
    CACHE_VERSION = 1

    def initialize(percent:)
      @percent = percent.to_i
    end

    def coupon_id
      return nil unless percent.positive?
      return nil unless stripe_configured?

      Rails.cache.fetch(cache_key, expires_in: 12.hours) { ensure_coupon }
    end

    private

    attr_reader :percent

    def ensure_coupon
      existing = find_coupon
      return existing.id if existing

      Stripe.api_key = ENV["STRIPE_PRIVATE_KEY"]
      Stripe::Coupon.create(
        name: "Referral #{percent}% off",
        percent_off: percent,
        duration: "forever",
        metadata: {
          kind: "referral_default",
          percent: percent.to_s
        }
      ).id
    rescue StandardError => e
      Rails.logger.error("[Billing::ReferralCoupon] failed to ensure coupon percent=#{percent}: #{e.class} - #{e.message}")
      nil
    end

    def find_coupon
      Stripe.api_key = ENV["STRIPE_PRIVATE_KEY"]
      coupons = Stripe::Coupon.list(limit: 100)
      coupons.data.find do |coupon|
        coupon.metadata&.[]("kind") == "referral_default" && coupon.percent_off.to_i == percent
      end
    rescue StandardError => e
      Rails.logger.warn("[Billing::ReferralCoupon] failed to lookup coupon percent=#{percent}: #{e.class} - #{e.message}")
      nil
    end

    def stripe_configured?
      ENV["STRIPE_PRIVATE_KEY"].present?
    end

    def cache_key
      "billing/referral_coupon/v#{CACHE_VERSION}/percent_#{percent}"
    end
  end
end
