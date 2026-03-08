module Billing
  class StripePromotionCodeSync
    COUPON_DURATION = "once".freeze

    def initialize(promotion_code:, replace_remote_objects: false, logger: Rails.logger)
      @promotion_code = promotion_code
      @replace_remote_objects = replace_remote_objects
      @logger = logger
    end

    def call
      return promotion_code unless stripe_configured?
      return promotion_code if promotion_code.stripe_coupon_id.blank? && promotion_code.stripe_promotion_code_id.blank? && !replace_remote_objects

      if replace_remote_objects || promotion_code.stripe_coupon_id.blank? || promotion_code.stripe_promotion_code_id.blank?
        replace_remote_objects!
      else
        sync_remote_state!
      end

      promotion_code
    end

    private

    attr_reader :promotion_code, :replace_remote_objects, :logger

    def replace_remote_objects!
      safely_deactivate_existing_remote!

      coupon = Stripe::Coupon.create(coupon_payload)
      stripe_promotion = Stripe::PromotionCode.create(promotion_code_payload(coupon.id))

      promotion_code.update_columns(
        stripe_coupon_id: coupon.id,
        stripe_promotion_code_id: stripe_promotion.id,
        updated_at: Time.current
      )
    end

    def sync_remote_state!
      Stripe::PromotionCode.update(
        promotion_code.stripe_promotion_code_id,
        { active: remotely_active? }
      )
    end

    def safely_deactivate_existing_remote!
      return if promotion_code.stripe_promotion_code_id.blank?

      Stripe::PromotionCode.update(promotion_code.stripe_promotion_code_id, { active: false })
    rescue StandardError => e
      logger.warn(
        "[Billing::StripePromotionCodeSync] failed to deactivate stale remote promotion_code_id=#{promotion_code.stripe_promotion_code_id}: #{e.class} - #{e.message}"
      )
    end

    def coupon_payload
      {
        name: coupon_name,
        percent_off: promotion_code.percent_off,
        duration: COUPON_DURATION,
        metadata: remote_metadata
      }
    end

    def promotion_code_payload(coupon_id)
      {
        promotion: {
          type: "coupon",
          coupon: coupon_id
        },
        code: promotion_code.code,
        active: remotely_active?,
        expires_at: promotion_code.expires_at&.to_i,
        max_redemptions: promotion_code.max_redemptions,
        metadata: remote_metadata
      }.compact
    end

    def remotely_active?
      promotion_code.active? && !promotion_code.archived? && !promotion_code.expired?
    end

    def coupon_name
      "#{promotion_code.code} #{promotion_code.percent_off}% off"
    end

    def remote_metadata
      {
        kind: "dashboard_promotion",
        promotion_code_id: promotion_code.id.to_s,
        promotion_code: promotion_code.code
      }
    end

    def stripe_configured?
      ENV["STRIPE_PRIVATE_KEY"].present?
    end
  end
end
