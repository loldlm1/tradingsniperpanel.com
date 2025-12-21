module Partners
  class ReferralCoupon
    CACHE_VERSION = 1

    def initialize(partner_profile:, percent:)
      @partner_profile = partner_profile
      @percent = percent.to_i
    end

    def coupon_id
      return nil unless percent.positive?
      return nil unless stripe_configured?
      return ensure_coupon if partner_profile.nil?

      Rails.cache.fetch(cache_key, expires_in: 12.hours) { ensure_coupon }
    end

    private

    attr_reader :partner_profile, :percent

    def ensure_coupon
      existing = find_coupon
      return existing.id if existing&.id

      Stripe.api_key = ENV["STRIPE_PRIVATE_KEY"]
      created = Stripe::Coupon.create(
        name: "Referral #{percent}% off (Partner ##{partner_profile&.id || 'unknown'})",
        percent_off: percent,
        duration: "forever",
        metadata: coupon_metadata
      )
      partner_profile&.update_column(:stripe_coupon_id, created.id) if partner_profile.present? && created&.id
      created.id
    rescue StandardError => e
      Rails.logger.warn("[Partners::ReferralCoupon] failed to ensure coupon partner_profile_id=#{partner_profile&.id} percent=#{percent}: #{e.class} - #{e.message}")
      nil
    end

    def find_coupon
      if partner_profile&.stripe_coupon_id.present?
        coupon = retrieve_coupon(partner_profile.stripe_coupon_id)
        return coupon if coupon&.percent_off.to_i == percent
      end

      Stripe.api_key = ENV["STRIPE_PRIVATE_KEY"]
      coupons = Stripe::Coupon.list(limit: 100)
      coupons.data.find do |coupon|
        coupon.metadata&.[]("kind") == "referral_partner" &&
          coupon.metadata&.[]("partner_profile_id").to_s == partner_profile&.id.to_s &&
          coupon.percent_off.to_i == percent
      end
    rescue StandardError => e
      Rails.logger.warn("[Partners::ReferralCoupon] failed to lookup coupon partner_profile_id=#{partner_profile&.id} percent=#{percent}: #{e.class} - #{e.message}")
      nil
    end

    def retrieve_coupon(coupon_id)
      Stripe.api_key = ENV["STRIPE_PRIVATE_KEY"]
      Stripe::Coupon.retrieve(coupon_id)
    rescue StandardError => e
      Rails.logger.warn("[Partners::ReferralCoupon] failed to retrieve coupon #{coupon_id}: #{e.class} - #{e.message}")
      nil
    end

    def stripe_configured?
      ENV["STRIPE_PRIVATE_KEY"].present?
    end

    def cache_key
      "partners/referral_coupon/v#{CACHE_VERSION}/partner_profile_#{partner_profile&.id}/percent_#{percent}"
    end

    def coupon_metadata
      {
        kind: "referral_partner",
        partner_profile_id: partner_profile&.id&.to_s,
        percent: percent.to_s
      }.compact
    end
  end
end
