require "securerandom"

module Billing
  class StripeSubscriptionSchedule
    UPDATABLE_STATUSES = %w[not_started active].freeze
    TERMINAL_STATUSES = %w[released canceled completed].freeze

    def initialize(subscription:, logger: Rails.logger)
      @subscription = subscription
      @logger = logger
    end

    def schedule_downgrade(target_price_id:, effective_at:)
      Stripe.api_key = ENV["STRIPE_PRIVATE_KEY"]
      schedule_id = existing_schedule_id
      created = false
      retried = false
      retry_suffix = nil
      schedule = nil

      begin
        if schedule_id.present?
          schedule = retrieve_schedule(schedule_id)
          if schedule == :missing
            clear_schedule_metadata
            schedule_id = nil
            schedule = nil
          elsif !updatable_schedule?(schedule)
            clear_schedule_metadata
            schedule_id = nil
          end
        end

        if schedule_id.blank?
          schedule = Stripe::SubscriptionSchedule.create(
            {
              from_subscription: subscription.processor_id
            },
            { idempotency_key: idempotency_key(target_price_id, effective_at, retry_suffix:) }
          )
          schedule_id = schedule.id
          created = true
        end

        schedule = Stripe::SubscriptionSchedule.update(
          schedule_id,
          {
            end_behavior: "release",
            phases: phases_for(target_price_id:, effective_at:)
          }
        )

        schedule
      rescue Stripe::InvalidRequestError => e
        if !retried && released_schedule_error?(e)
          retried = true
          retry_suffix = "retry-#{SecureRandom.hex(4)}"
          clear_schedule_metadata
          schedule_id = nil
          created = false
          retry
        end
        release_created_schedule(schedule_id) if created && schedule_id.present?
        logger.error(
          "[Billing::StripeSubscriptionSchedule] schedule failed subscription_id=#{subscription.id} processor_id=#{subscription.processor_id} target_price_id=#{target_price_id}: #{e.class} - #{e.message}"
        )
        raise
      rescue StandardError => e
        release_created_schedule(schedule_id) if created && schedule_id.present?
        logger.error(
          "[Billing::StripeSubscriptionSchedule] schedule failed subscription_id=#{subscription.id} processor_id=#{subscription.processor_id} target_price_id=#{target_price_id}: #{e.class} - #{e.message}"
        )
        raise
      end
    end

    def release(schedule_id)
      return if schedule_id.blank?

      Stripe.api_key = ENV["STRIPE_PRIVATE_KEY"]
      schedule = retrieve_schedule(schedule_id)
      if schedule == :missing
        clear_schedule_metadata
        return
      end
      return if schedule && terminal_schedule?(schedule)

      Stripe::SubscriptionSchedule.release(schedule_id)
    rescue Stripe::InvalidRequestError => e
      return if released_schedule_error?(e)

      logger.error(
        "[Billing::StripeSubscriptionSchedule] release failed subscription_id=#{subscription.id} schedule_id=#{schedule_id}: #{e.class} - #{e.message}"
      )
      raise
    rescue StandardError => e
      logger.error(
        "[Billing::StripeSubscriptionSchedule] release failed subscription_id=#{subscription.id} schedule_id=#{schedule_id}: #{e.class} - #{e.message}"
      )
      raise
    end

    def managed_schedule_id
      Stripe.api_key = ENV["STRIPE_PRIVATE_KEY"]

      schedule_id = existing_schedule_id
      return if schedule_id.blank?

      schedule = retrieve_schedule(schedule_id)
      if schedule == :missing
        clear_schedule_metadata
        return
      end
      return if schedule && terminal_schedule?(schedule)

      schedule_id
    end

    private

    attr_reader :subscription, :logger

    def existing_schedule_id
      metadata = (subscription.metadata || {}).to_h
      schedule_id = metadata["scheduled_schedule_id"] || metadata[:scheduled_schedule_id]
      return schedule_id if schedule_id.present?

      stripe_subscription = Stripe::Subscription.retrieve(subscription.processor_id)
      schedule = stripe_subscription.respond_to?(:schedule) ? stripe_subscription.schedule : nil
      return schedule.id if schedule.respond_to?(:id)

      schedule.to_s.presence
    rescue StandardError => e
      logger.warn(
        "[Billing::StripeSubscriptionSchedule] schedule lookup failed subscription_id=#{subscription.id} processor_id=#{subscription.processor_id}: #{e.class} - #{e.message}"
      )
      nil
    end

    def retrieve_schedule(schedule_id)
      return if schedule_id.blank?

      Stripe::SubscriptionSchedule.retrieve(schedule_id)
    rescue Stripe::InvalidRequestError => e
      if missing_schedule_error?(e)
        logger.warn(
          "[Billing::StripeSubscriptionSchedule] schedule missing subscription_id=#{subscription.id} schedule_id=#{schedule_id}"
        )
        return :missing
      end
      logger.warn(
        "[Billing::StripeSubscriptionSchedule] schedule retrieve failed subscription_id=#{subscription.id} schedule_id=#{schedule_id}: #{e.class} - #{e.message}"
      )
      nil
    rescue StandardError => e
      logger.warn(
        "[Billing::StripeSubscriptionSchedule] schedule retrieve failed subscription_id=#{subscription.id} schedule_id=#{schedule_id}: #{e.class} - #{e.message}"
      )
      nil
    end

    def release_created_schedule(schedule_id)
      Stripe::SubscriptionSchedule.release(schedule_id)
    rescue StandardError => e
      logger.warn(
        "[Billing::StripeSubscriptionSchedule] cleanup release failed subscription_id=#{subscription.id} schedule_id=#{schedule_id}: #{e.class} - #{e.message}"
      )
    end

    def clear_schedule_metadata
      metadata = (subscription.metadata || {}).to_h
      changed = false
      %w[scheduled_plan_key scheduled_change_at scheduled_schedule_id].each do |key|
        next unless metadata.key?(key)

        metadata.delete(key)
        changed = true
      end
      subscription.update!(metadata: metadata) if changed
    rescue StandardError => e
      logger.warn(
        "[Billing::StripeSubscriptionSchedule] failed to clear metadata subscription_id=#{subscription.id}: #{e.class} - #{e.message}"
      )
    end

    def released_schedule_error?(error)
      message = error.message.to_s.downcase
      message.include?("released") ||
        message.include?("canceled") ||
        message.include?("no such subscription schedule")
    end

    def missing_schedule_error?(error)
      error.message.to_s.downcase.include?("no such subscription schedule")
    end

    def updatable_schedule?(schedule)
      return false if schedule.nil?

      status = schedule_status(schedule)
      status.blank? || UPDATABLE_STATUSES.include?(status)
    end

    def terminal_schedule?(schedule)
      status = schedule_status(schedule)
      status.present? && TERMINAL_STATUSES.include?(status)
    end

    def schedule_status(schedule)
      return schedule.status.to_s if schedule.respond_to?(:status)
      return schedule[:status].to_s if schedule.is_a?(Hash)

      nil
    end

    def phase_start
      if subscription.current_period_start.present?
        subscription.current_period_start.to_i
      else
        Time.current.to_i
      end
    end

    def phases_for(target_price_id:, effective_at:)
      [
        {
          items: [{ price: subscription.processor_plan, quantity: subscription.quantity || 1 }],
          start_date: phase_start,
          end_date: effective_at.to_i
        },
        {
          items: [{ price: target_price_id, quantity: subscription.quantity || 1 }],
          start_date: effective_at.to_i
        }
      ]
    end

    def idempotency_key(target_price_id, effective_at, retry_suffix: nil)
      parts = [
        "schedule",
        subscription.processor_id,
        target_price_id,
        effective_at.to_i
      ]
      parts << retry_suffix if retry_suffix.present?
      parts.join(":")
    end
  end
end
