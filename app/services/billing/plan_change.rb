module Billing
  class PlanChange
    Result = Struct.new(:status, :price_key, :effective_at, :error, keyword_init: true) do
      def success?
        %i[upgraded downgrade_scheduled].include?(status)
      end
    end

    def initialize(subscription:, price_key:, user:, logger: Rails.logger)
      @subscription = subscription
      @price_key = price_key
      @user = user
      @logger = logger
      @scheduled_change = Billing::ScheduledPlanChange.new(subscription: subscription, logger: logger)
    end

    def call
      return Result.new(status: :invalid_price) if price_key.blank?

      target_price_id = Billing::ConfiguredPrices.price_id_for(price_key)
      return Result.new(status: :invalid_price) if target_price_id.blank?

      current_price_id = subscription.processor_plan
      current_price_key = Billing::PriceKeyResolver.key_for_price_id(current_price_id)
      return Result.new(status: :already_current, price_key: price_key) if current_price_key == price_key

      direction = plan_comparator.compare(
        current_key: current_price_key,
        target_key: price_key,
        current_price_id: current_price_id,
        target_price_id: target_price_id
      )

      subscription.with_lock do
        if direction == :downgrade
          schedule_downgrade(target_price_id)
        else
          upgrade_subscription(target_price_id)
        end
      end
    rescue StandardError => e
      logger.error(
        "[Billing::PlanChange] failed user_id=#{user&.id} subscription_id=#{subscription&.id} price_key=#{price_key}: #{e.class} - #{e.message}"
      )
      Result.new(status: :error, error: e)
    end

    private

    attr_reader :subscription, :price_key, :user, :logger, :scheduled_change

    def plan_comparator
      @plan_comparator ||= Billing::PlanComparator.new(
        pricing_catalog: Billing::PricingCatalog.new.call,
        stripe_fallback: true,
        logger: logger
      )
    end

    def schedule_downgrade(target_price_id)
      effective_at = subscription.current_period_end
      return Result.new(status: :cannot_schedule) if effective_at.blank?

      existing = scheduled_change.fetch(current_price_key: current_price_key)
      if existing&.dig(:price_key) == price_key && existing[:effective_at].present?
        return Result.new(status: :downgrade_scheduled, price_key: price_key, effective_at: existing[:effective_at])
      end

      if existing&.dig(:schedule_id).present?
        stripe_schedule.release(existing[:schedule_id])
      end

      schedule = stripe_schedule.schedule_downgrade(
        target_price_id: target_price_id,
        effective_at: effective_at,
        user_id: user&.id,
        target_price_key: price_key
      )

      scheduled_change.store!(
        price_key: price_key,
        schedule_id: schedule.id,
        effective_at: effective_at
      )

      subscription.reload
      verified = scheduled_change.fetch(current_price_key: current_price_key)
      unless verified
        logger.warn(
          "[Billing::PlanChange] scheduled change verification failed subscription_id=#{subscription.id} price_key=#{price_key}"
        )
        return Result.new(status: :error)
      end

      Result.new(status: :downgrade_scheduled, price_key: verified[:price_key], effective_at: verified[:effective_at])
    end

    def upgrade_subscription(target_price_id)
      existing = scheduled_change.fetch(current_price_key: current_price_key)
      if existing&.dig(:schedule_id).present?
        stripe_schedule.release(existing[:schedule_id])
        scheduled_change.clear!
      end

      subscription.swap(target_price_id, proration_behavior: "always_invoice")
      Result.new(status: :upgraded, price_key: price_key)
    end

    def current_price_key
      @current_price_key ||= Billing::PriceKeyResolver.key_for_price_id(subscription.processor_plan)
    end

    def stripe_schedule
      @stripe_schedule ||= Billing::StripeSubscriptionSchedule.new(subscription: subscription, logger: logger)
    end
  end
end
