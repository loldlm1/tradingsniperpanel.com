module Billing
  class OneTimePurchaseNotification
    def initialize(user:, charge:, plans:, logger: Rails.logger)
      @user = user
      @charge = charge
      @plans = plans
      @logger = logger
    end

    def call
      return unless user.is_a?(User)
      return unless charge.is_a?(Pay::Charge)

      plan_names = plans.filter_map(&:name).uniq
      return if plan_names.empty?

      event_key = "one_time_purchase_confirmed:#{charge.processor_id}"
      saved = Billing::EmailDeliveryTracker.record_once(
        event_key: event_key,
        event_type: "one_time_purchase_confirmed",
        user_id: user.id,
        pay_charge_id: charge.id,
        metadata: {
          plan_names: plan_names,
          stripe_charge_id: charge.processor_id
        }
      )
      unless saved
        logger.info("[Billing::OneTimePurchaseNotification] skipped duplicate stripe_charge_id=#{charge.processor_id}")
        return
      end

      with_user_locale do
        BillingNotificationsMailer.with(
          user: user,
          plan_names: plan_names,
          amount_cents: charge.amount.to_i,
          currency: charge.currency,
          charge_id: charge.processor_id,
          receipt_url: receipt_url_for(charge)
        ).one_time_purchase_confirmed.deliver_later
      end
    rescue StandardError => e
      logger.error("[Billing::OneTimePurchaseNotification] failed pay_charge_id=#{charge&.id} user_id=#{user&.id}: #{e.class} - #{e.message}")
      raise
    end

    private

    attr_reader :user, :charge, :plans, :logger

    def receipt_url_for(charge)
      if charge.respond_to?(:stripe_receipt_url)
        receipt = charge.stripe_receipt_url
        return receipt if receipt.present?
      end

      data = charge.respond_to?(:data) ? charge.data : nil
      return unless data.is_a?(Hash)

      data["stripe_receipt_url"].presence
    end

    def with_user_locale
      locale = user.preferred_locale_code.presence || I18n.default_locale
      I18n.with_locale(locale) { yield }
    end
  end
end
