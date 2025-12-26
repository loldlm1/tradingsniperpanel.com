module Billing
  class StripeSubscriptionSchedule
    def initialize(subscription:, logger: Rails.logger)
      @subscription = subscription
      @logger = logger
    end

    def schedule_downgrade(target_price_id:, effective_at:, user_id:, target_price_key:)
      Stripe.api_key = ENV["STRIPE_PRIVATE_KEY"]
      schedule_id = existing_schedule_id
      created = schedule_id.blank?
      schedule = nil

      if created
        schedule = Stripe::SubscriptionSchedule.create(
          {
            from_subscription: subscription.processor_id,
            metadata: schedule_metadata(user_id:, target_price_key:)
          },
          { idempotency_key: idempotency_key(target_price_id, effective_at) }
        )
        schedule_id = schedule.id
      end

      schedule = Stripe::SubscriptionSchedule.update(
        schedule_id,
        {
          end_behavior: "release",
          metadata: schedule_metadata(user_id:, target_price_key:),
          phases: phases_for(target_price_id:, effective_at:)
        }
      )

      schedule
    rescue StandardError => e
      release_created_schedule(schedule_id) if created && schedule_id.present?
      logger.error(
        "[Billing::StripeSubscriptionSchedule] schedule failed subscription_id=#{subscription.id} processor_id=#{subscription.processor_id} target_price_id=#{target_price_id}: #{e.class} - #{e.message}"
      )
      raise
    end

    def release(schedule_id)
      return if schedule_id.blank?

      Stripe.api_key = ENV["STRIPE_PRIVATE_KEY"]
      Stripe::SubscriptionSchedule.release(schedule_id)
    rescue StandardError => e
      logger.error(
        "[Billing::StripeSubscriptionSchedule] release failed subscription_id=#{subscription.id} schedule_id=#{schedule_id}: #{e.class} - #{e.message}"
      )
      raise
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

    def release_created_schedule(schedule_id)
      Stripe::SubscriptionSchedule.release(schedule_id)
    rescue StandardError => e
      logger.warn(
        "[Billing::StripeSubscriptionSchedule] cleanup release failed subscription_id=#{subscription.id} schedule_id=#{schedule_id}: #{e.class} - #{e.message}"
      )
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

    def schedule_metadata(user_id:, target_price_key:)
      {
        "client_reference_id" => user_id.to_s,
        "scheduled_plan_key" => target_price_key,
        "origin" => "dashboard_plans"
      }
    end

    def idempotency_key(target_price_id, effective_at)
      [
        "schedule",
        subscription.processor_id,
        target_price_id,
        effective_at.to_i
      ].join(":")
    end
  end
end
