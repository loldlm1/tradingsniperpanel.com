require "securerandom"

module Billing
  class StripeSubscriptionSchedule
    UPDATABLE_STATUSES = %w[not_started active].freeze
    TERMINAL_STATUSES = %w[released canceled completed].freeze
    CATALOG_MANAGED_BY = "pandora_catalog_reconciler".freeze

    ConflictingScheduleError = Class.new(StandardError)
    CatalogTransition = Struct.new(:schedule, :created, keyword_init: true)

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
      schedule_id = normalize_schedule_id(schedule_id)
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

    def schedule_catalog_transition(target_price_id:, target_plan_key:, effective_at:, migration_key:)
      Stripe.api_key = ENV["STRIPE_PRIVATE_KEY"]
      metadata = catalog_metadata(
        target_price_id: target_price_id,
        target_plan_key: target_plan_key,
        effective_at: effective_at,
        migration_key: migration_key
      )
      schedule_id = strict_remote_schedule_id
      schedule = strict_retrieve_schedule(schedule_id) if schedule_id.present?

      if schedule && !terminal_schedule?(schedule)
        schedule = recover_created_catalog_schedule(schedule, metadata) unless catalog_schedule_owned?(schedule, metadata)

        if catalog_transition_matches?(
          schedule,
          target_price_id: target_price_id,
          target_plan_key: target_plan_key,
          effective_at: effective_at,
          migration_key: migration_key
        )
          return CatalogTransition.new(schedule: schedule, created: false)
        end

        raise_elapsed_transition_conflict(schedule) if transition_elapsed?(effective_at)
      end

      created = schedule_id.blank? || terminal_schedule?(schedule)
      raise_elapsed_transition_conflict(schedule) if created && transition_elapsed?(effective_at)

      if created
        schedule = Stripe::SubscriptionSchedule.create(
          { from_subscription: subscription.processor_id },
          { idempotency_key: catalog_idempotency_key(metadata) }
        )
        schedule_id = schedule.id
      end

      schedule = Stripe::SubscriptionSchedule.update(
        schedule_id,
        {
          end_behavior: "release",
          metadata: metadata,
          phases: phases_for(target_price_id: target_price_id, effective_at: effective_at)
        }
      )
      unless catalog_transition_matches?(
        schedule,
        target_price_id: target_price_id,
        target_plan_key: target_plan_key,
        effective_at: effective_at,
        migration_key: migration_key
      )
        raise "Stripe schedule verification failed for subscription #{subscription.processor_id}"
      end

      CatalogTransition.new(schedule: schedule, created: created)
    rescue StandardError => e
      logger.error(
        "[Billing::StripeSubscriptionSchedule] catalog transition failed " \
        "subscription_id=#{subscription.id} processor_id=#{subscription.processor_id}: #{e.class} - #{e.message}"
      )
      raise
    end

    def verify_catalog_transition(schedule_id:, target_price_id:, target_plan_key:, effective_at:, migration_key:)
      Stripe.api_key = ENV["STRIPE_PRIVATE_KEY"]
      schedule = strict_retrieve_schedule(schedule_id)
      catalog_transition_matches?(
        schedule,
        target_price_id: target_price_id,
        target_plan_key: target_plan_key,
        effective_at: effective_at,
        migration_key: migration_key
      )
    end

    private

    attr_reader :subscription, :logger

    def existing_schedule_id
      metadata = (subscription.metadata || {}).to_h
      schedule_id = normalize_schedule_id(metadata["scheduled_schedule_id"] || metadata[:scheduled_schedule_id])
      return schedule_id if schedule_id.present?

      stripe_subscription = Stripe::Subscription.retrieve(subscription.processor_id)
      schedule = stripe_subscription.respond_to?(:schedule) ? stripe_subscription.schedule : nil
      normalize_schedule_id(schedule)
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
          items: [ { price: subscription.processor_plan, quantity: subscription.quantity || 1 } ],
          start_date: phase_start,
          end_date: effective_at.to_i
        },
        {
          items: [ { price: target_price_id, quantity: subscription.quantity || 1 } ],
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

    def normalize_schedule_id(value)
      return if value.blank?
      return value if value.is_a?(String)
      return value["id"] if value.is_a?(Hash) && value["id"].present?
      return value[:id] if value.is_a?(Hash) && value[:id].present?
      return if value.is_a?(Hash)
      return value.id if value.respond_to?(:id) && value.id.present?

      value.to_s.presence
    end

    def strict_remote_schedule_id
      stripe_subscription = Stripe::Subscription.retrieve(subscription.processor_id)
      schedule = stripe_subscription.respond_to?(:schedule) ? stripe_subscription.schedule : nil
      normalize_schedule_id(schedule)
    end

    def strict_retrieve_schedule(schedule_id)
      return if schedule_id.blank?

      Stripe::SubscriptionSchedule.retrieve(schedule_id)
    end

    def recover_created_catalog_schedule(schedule, metadata)
      raise_conflicting_schedule(schedule) if schedule_metadata(schedule).present?

      replayed = Stripe::SubscriptionSchedule.create(
        { from_subscription: subscription.processor_id },
        { idempotency_key: catalog_idempotency_key(metadata) }
      )
      return replayed if normalize_schedule_id(replayed) == normalize_schedule_id(schedule)

      raise_conflicting_schedule(schedule)
    rescue Stripe::InvalidRequestError
      raise_conflicting_schedule(schedule)
    end

    def raise_conflicting_schedule(schedule)
      raise ConflictingScheduleError,
            "subscription #{subscription.processor_id} has unmanaged schedule #{normalize_schedule_id(schedule)}"
    end

    def raise_elapsed_transition_conflict(schedule)
      schedule_id = normalize_schedule_id(schedule) || "none"
      raise ConflictingScheduleError,
            "subscription #{subscription.processor_id} has elapsed catalog transition with non-matching schedule #{schedule_id}"
    end

    def transition_elapsed?(effective_at)
      effective_at.to_i <= Time.current.to_i
    end

    def catalog_metadata(target_price_id:, target_plan_key:, effective_at:, migration_key:)
      {
        "managed_by" => CATALOG_MANAGED_BY,
        "migration_key" => migration_key.to_s,
        "pay_subscription_id" => subscription.id.to_s,
        "source_price_id" => subscription.processor_plan.to_s,
        "target_plan_key" => target_plan_key.to_s,
        "target_price_id" => target_price_id.to_s,
        "effective_at" => effective_at.to_i.to_s
      }
    end

    def catalog_schedule_owned?(schedule, expected_metadata)
      metadata = schedule_metadata(schedule)
      expected_metadata.all? { |key, value| metadata[key].to_s == value.to_s }
    end

    def catalog_transition_matches?(schedule, target_price_id:, target_plan_key:, effective_at:, migration_key:)
      return false if schedule.blank? || terminal_schedule?(schedule)

      expected_metadata = catalog_metadata(
        target_price_id: target_price_id,
        target_plan_key: target_plan_key,
        effective_at: effective_at,
        migration_key: migration_key
      )
      return false unless catalog_schedule_owned?(schedule, expected_metadata)
      return false unless value_for(schedule, :end_behavior).to_s == "release"

      phases = schedule_phases(schedule).last(2)
      return false unless phases.size == 2

      current_phase, target_phase = phases
      current_item = phase_items(current_phase).first
      target_item = phase_items(target_phase).first
      expected_quantity = subscription.quantity || 1

      phase_price_id(current_item) == subscription.processor_plan.to_s &&
        phase_quantity(current_item) == expected_quantity &&
        phase_end_epoch(current_phase) == effective_at.to_i &&
        phase_price_id(target_item) == target_price_id.to_s &&
        phase_quantity(target_item) == expected_quantity &&
        phase_start_epoch(target_phase) == effective_at.to_i
    end

    def schedule_metadata(schedule)
      metadata = value_for(schedule, :metadata)
      metadata.respond_to?(:to_h) ? metadata.to_h.stringify_keys : {}
    end

    def schedule_phases(schedule)
      collection_for(value_for(schedule, :phases))
    end

    def phase_items(phase)
      collection_for(value_for(phase, :items))
    end

    def collection_for(value)
      return value.data.to_a if value.respond_to?(:data)

      Array(value)
    end

    def phase_price_id(item)
      price = value_for(item, :price)
      normalize_schedule_id(price).to_s
    end

    def phase_quantity(item)
      value_for(item, :quantity).to_i
    end

    def phase_start_epoch(phase)
      value_for(phase, :start_date).to_i
    end

    def phase_end_epoch(phase)
      value_for(phase, :end_date).to_i
    end

    def value_for(source, key)
      return if source.blank?
      return source.public_send(key) if source.respond_to?(key)
      return source[key] || source[key.to_s] if source.is_a?(Hash)

      nil
    end

    def catalog_idempotency_key(metadata)
      [
        "pandora-catalog",
        metadata.fetch("migration_key"),
        subscription.processor_id,
        metadata.fetch("target_price_id"),
        metadata.fetch("effective_at")
      ].join(":")
    end
  end
end
