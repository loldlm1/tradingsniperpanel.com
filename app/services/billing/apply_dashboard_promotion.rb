module Billing
  class ApplyDashboardPromotion
    def initialize(user:, checkout_params:, promotion_code_id: nil, logger: Rails.logger)
      @user = user
      @checkout_params = checkout_params
      @promotion_code_id = promotion_code_id
      @logger = logger
    end

    def call
      return checkout_params unless user.is_a?(User)
      return checkout_params if checkout_params[:discounts].present?

      promotion = resolved_promotion
      return checkout_params unless promotion&.active_for_checkout?

      with_discount = checkout_params.deep_dup
      with_discount.delete(:allow_promotion_codes)
      with_discount[:discounts] = [{ promotion_code: promotion.stripe_promotion_code_id }]
      merge_metadata!(with_discount, promotion_metadata(promotion))
      with_discount
    rescue StandardError => e
      logger.warn("[Billing::ApplyDashboardPromotion] failed user_id=#{user&.id} promotion_code_id=#{promotion_code_id}: #{e.class} - #{e.message}")
      checkout_params
    end

    private

    attr_reader :user, :checkout_params, :promotion_code_id, :logger

    def resolved_promotion
      return nil if promotion_code_id.blank?

      PromotionCode.active.find_by(id: promotion_code_id)
    end

    def promotion_metadata(promotion)
      {
        "dashboard_promotion_id" => promotion.id.to_s,
        "dashboard_promotion_code" => promotion.code,
        "dashboard_promotion_percent" => promotion.percent_off.to_s
      }
    end

    def merge_metadata!(params, metadata)
      return if metadata.blank?

      params[:metadata] = (params[:metadata] || {}).merge(metadata)

      if params[:payment_intent_data].present? || params[:mode].to_s == "payment"
        params[:payment_intent_data] ||= {}
        params[:payment_intent_data][:metadata] = (params[:payment_intent_data][:metadata] || {}).merge(metadata)
      end

      if params[:subscription_data].present? || params[:mode].to_s == "subscription"
        params[:subscription_data] ||= {}
        params[:subscription_data][:metadata] = (params[:subscription_data][:metadata] || {}).merge(metadata)
      end
    end
  end
end
