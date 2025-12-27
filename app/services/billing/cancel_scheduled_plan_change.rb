module Billing
  class CancelScheduledPlanChange
    Result = Struct.new(:status, :price_key, :schedule_id, :error, keyword_init: true) do
      def success?
        status == :canceled
      end
    end

    def initialize(subscription:, logger: Rails.logger)
      @subscription = subscription
      @logger = logger
      @scheduled_change = Billing::ScheduledPlanChange.new(subscription: subscription, logger: logger)
      @stripe_schedule = Billing::StripeSubscriptionSchedule.new(subscription: subscription, logger: logger)
    end

    def call
      return Result.new(status: :no_subscription) if subscription.blank?

      existing = scheduled_change.fetch
      return Result.new(status: :no_schedule) if existing.blank?

      schedule_id = existing[:schedule_id]
      stripe_schedule.release(schedule_id) if schedule_id.present?
      scheduled_change.clear!

      Result.new(status: :canceled, price_key: existing[:price_key], schedule_id: schedule_id)
    rescue StandardError => e
      logger.error(
        "[Billing::CancelScheduledPlanChange] failed subscription_id=#{subscription&.id}: #{e.class} - #{e.message}"
      )
      Result.new(status: :error, error: e)
    end

    private

    attr_reader :subscription, :logger, :scheduled_change, :stripe_schedule
  end
end
