module Billing
  class CancelSubscription
    Result = Struct.new(:status, :ends_at, :schedule_status, :error, keyword_init: true) do
      def success?
        %i[canceled already_canceled].include?(status)
      end
    end

    def initialize(subscription:, user: nil, logger: Rails.logger, locale: I18n.locale)
      @subscription = subscription
      @user = user
      @logger = logger
      @locale = locale
      @scheduled_change = Billing::CancelScheduledPlanChange.new(subscription: subscription, logger: logger)
    end

    def call
      return Result.new(status: :no_subscription) if subscription.blank?

      schedule_result = scheduled_change.call
      if schedule_result.status == :error
        logger.error(
          "[Billing::CancelSubscription] schedule cleanup failed user_id=#{user&.id} subscription_id=#{subscription&.id} processor_id=#{subscription&.processor_id} locale=#{locale}: #{schedule_result.error&.class} - #{schedule_result.error&.message}"
        )
        return Result.new(status: :schedule_error, schedule_status: schedule_result.status, error: schedule_result.error)
      end

      return Result.new(status: :already_canceled, ends_at: subscription.ends_at, schedule_status: schedule_result.status) if already_canceled?

      subscription.cancel
      subscription.sync! if subscription.respond_to?(:sync!)
      subscription.reload

      Result.new(status: :canceled, ends_at: subscription.ends_at, schedule_status: schedule_result.status)
    rescue StandardError => e
      logger.error(
        "[Billing::CancelSubscription] failed user_id=#{user&.id} subscription_id=#{subscription&.id} processor_id=#{subscription&.processor_id} locale=#{locale}: #{e.class} - #{e.message}"
      )
      Result.new(status: :error, schedule_status: schedule_result&.status, error: e)
    end

    private

    attr_reader :subscription, :user, :logger, :locale, :scheduled_change

    def already_canceled?
      return true if subscription.ends_at.present?

      status = subscription.status.to_s
      status == "canceled" || status == "cancelled"
    end
  end
end
