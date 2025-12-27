module Billing
  class PlanChange
    Result = Struct.new(:status, :price_key, :effective_at, :error, keyword_init: true) do
      def success?
        %i[upgraded downgrade_scheduled].include?(status)
      end
    end

    DEADLOCK_RETRIES = 2

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

      if direction == :downgrade
        subscription.with_lock { schedule_downgrade(target_price_id) }
      else
        with_deadlock_retry(target_price_id) { upgrade_subscription(target_price_id) }
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
        effective_at: effective_at
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
      release_managed_schedule
      subscription.swap(target_price_id, proration_behavior: "always_invoice")
      Result.new(status: :upgraded, price_key: price_key)
    rescue Pay::Stripe::Error => e
      raise unless managed_schedule_error?(e)

      release_managed_schedule

      subscription.reload
      subscription.swap(target_price_id, proration_behavior: "always_invoice")
      Result.new(status: :upgraded, price_key: price_key)
    end

    def current_price_key
      @current_price_key ||= Billing::PriceKeyResolver.key_for_price_id(subscription.processor_plan)
    end

    def stripe_schedule
      @stripe_schedule ||= Billing::StripeSubscriptionSchedule.new(subscription: subscription, logger: logger)
    end

    def managed_schedule_error?(error)
      error.message.to_s.include?("managed by the subscription schedule")
    end

    def with_deadlock_retry(target_price_id)
      attempts = 0

      begin
        attempts += 1
        return yield
      rescue ActiveRecord::Deadlocked => e
        if upgraded_in_stripe?(target_price_id)
          logger.info(
            "[Billing::PlanChange] deadlock resolved by sync subscription_id=#{subscription.id} price_key=#{price_key}"
          )
          return Result.new(status: :upgraded, price_key: price_key)
        end

        if attempts <= DEADLOCK_RETRIES
          logger.warn(
            "[Billing::PlanChange] deadlock retry attempt=#{attempts} subscription_id=#{subscription.id} price_key=#{price_key}"
          )
          sleep(deadlock_backoff(attempts))
          retry
        end

        raise e
      end
    end

    def upgraded_in_stripe?(target_price_id)
      subscription.sync!
      subscription.processor_plan == target_price_id
    rescue StandardError => e
      logger.warn(
        "[Billing::PlanChange] sync after deadlock failed subscription_id=#{subscription.id}: #{e.class} - #{e.message}"
      )
      false
    end

    def deadlock_backoff(attempt)
      base = 0.05
      jitter = rand * 0.02
      base * attempt + jitter
    end

    def release_managed_schedule
      managed_schedule_id = stripe_schedule.managed_schedule_id
      stripe_schedule.release(managed_schedule_id) if managed_schedule_id.present?
      clear_scheduled_metadata if scheduled_metadata_present?
      managed_schedule_id
    end

    def clear_scheduled_metadata
      scheduled_change.clear!
    end

    def scheduled_metadata_present?
      metadata = (subscription.metadata || {}).to_h
      Billing::ScheduledPlanChange::METADATA_KEYS.any? do |key|
        metadata[key].present? || metadata[key.to_sym].present?
      end
    end
  end
end
