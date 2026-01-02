module Billing
  class ScheduledPlanChange
    METADATA_KEYS = %w[scheduled_plan_key scheduled_change_at scheduled_schedule_id].freeze

    def initialize(subscription:, logger: Rails.logger)
      @subscription = subscription
      @logger = logger
    end

    def fetch(current_price_key: nil)
      return nil unless subscription

      result = fetch_from_metadata
      result ||= fetch_from_stripe if result.blank?
      return nil if result.blank?

      if current_price_key.present? && result[:price_key] == current_price_key
        clear!
        return nil
      end

      effective_at = result[:effective_at]
      if effective_at.present? && effective_at <= Time.current && current_price_key.present? && result[:price_key] == current_price_key
        clear!
        return nil
      end

      result
    end

    def store!(price_key:, schedule_id:, effective_at:)
      update_metadata!(
        "scheduled_plan_key" => price_key,
        "scheduled_change_at" => effective_at&.iso8601,
        "scheduled_schedule_id" => schedule_id
      )
    end

    def clear!
      update_metadata!(
        "scheduled_plan_key" => nil,
        "scheduled_change_at" => nil,
        "scheduled_schedule_id" => nil
      )
    end

    private

    attr_reader :subscription, :logger

    def fetch_from_metadata
      metadata = normalized_metadata
      price_key = metadata["scheduled_plan_key"]
      return nil if price_key.blank?

      schedule_id = normalize_schedule_id(metadata["scheduled_schedule_id"])
      if schedule_id.present? && stripe_enabled?
        schedule = retrieve_schedule(schedule_id: schedule_id)
        if schedule == :missing
          clear!
          return nil
        end
        if terminal_schedule?(schedule)
          clear!
          return nil
        end
      end

      {
        price_key: price_key,
        effective_at: parse_time(metadata["scheduled_change_at"]),
        schedule_id: schedule_id
      }
    end

    def fetch_from_stripe
      return nil unless stripe_enabled?

      schedule = retrieve_schedule
      return nil if schedule.blank? || schedule == :missing
      if terminal_schedule?(schedule)
        clear!
        return nil
      end

      phase = target_phase(schedule)
      return nil if phase.blank?

      price_id = phase_price_id(phase)
      return nil if price_id.blank?

      price_key = Billing::PriceKeyResolver.key_for_price_id(price_id)
      return nil if price_key.blank?

      effective_at = phase_start_time(phase)
      schedule_id = schedule.respond_to?(:id) ? schedule.id : schedule.to_s
      result = {
        price_key: price_key,
        effective_at: effective_at,
        schedule_id: schedule_id
      }

      begin
        store!(price_key: price_key, schedule_id: schedule_id, effective_at: effective_at)
      rescue StandardError => e
        logger.warn(
          "[Billing::ScheduledPlanChange] failed to persist schedule metadata subscription_id=#{subscription.id}: #{e.class} - #{e.message}"
        )
      end

      result
    rescue StandardError => e
      logger.warn(
        "[Billing::ScheduledPlanChange] schedule lookup failed subscription_id=#{subscription.id}: #{e.class} - #{e.message}"
      )
      nil
    end

    def normalized_metadata
      (subscription.metadata || {}).to_h.stringify_keys
    end

    def stripe_enabled?
      ENV["STRIPE_PRIVATE_KEY"].present?
    end

    def retrieve_schedule(schedule_id: nil)
      Stripe.api_key = ENV["STRIPE_PRIVATE_KEY"]

      schedule_id ||= schedule_id_from_metadata || schedule_id_from_subscription_cache
      schedule_id ||= schedule_id_from_stripe_subscription
      return nil if schedule_id.blank?

      Stripe::SubscriptionSchedule.retrieve(schedule_id)
    rescue Stripe::InvalidRequestError => e
      if missing_schedule_error?(e)
        logger.warn(
          "[Billing::ScheduledPlanChange] schedule missing subscription_id=#{subscription.id} schedule_id=#{schedule_id}"
        )
        return :missing
      end
      logger.warn(
        "[Billing::ScheduledPlanChange] schedule retrieve failed subscription_id=#{subscription.id} schedule_id=#{schedule_id}: #{e.class} - #{e.message}"
      )
      nil
    rescue StandardError => e
      logger.warn(
        "[Billing::ScheduledPlanChange] schedule retrieve failed subscription_id=#{subscription.id} schedule_id=#{schedule_id}: #{e.class} - #{e.message}"
      )
      nil
    end

    def schedule_id_from_metadata
      normalize_schedule_id(normalized_metadata["scheduled_schedule_id"])
    end

    def schedule_id_from_subscription_cache
      cached = subscription.object.is_a?(Hash) ? subscription.object["schedule"] : nil
      cached = subscription.data.is_a?(Hash) ? subscription.data["schedule"] : cached
      normalize_schedule_id(cached)
    end

    def schedule_id_from_stripe_subscription
      stripe_subscription = Stripe::Subscription.retrieve(subscription.processor_id)
      schedule = stripe_subscription.respond_to?(:schedule) ? stripe_subscription.schedule : nil
      normalize_schedule_id(schedule)
    end

    def target_phase(schedule)
      phases = schedule.respond_to?(:phases) ? schedule.phases : nil
      Array(phases).max_by { |phase| phase_start_epoch(phase).to_i }
    end

    def terminal_schedule?(schedule)
      status = schedule_status(schedule)
      status.present? && %w[released canceled completed].include?(status)
    end

    def schedule_status(schedule)
      return schedule.status.to_s if schedule.respond_to?(:status)
      return schedule[:status].to_s if schedule.is_a?(Hash)

      nil
    end

    def missing_schedule_error?(error)
      error.message.to_s.downcase.include?("no such subscription schedule")
    end

    def phase_start_epoch(phase)
      return phase.start_date if phase.respond_to?(:start_date)
      return phase[:start_date] if phase.is_a?(Hash)

      nil
    end

    def phase_start_time(phase)
      epoch = phase_start_epoch(phase).to_i
      return if epoch.zero?

      Time.zone.at(epoch)
    end

    def phase_price_id(phase)
      items = phase.respond_to?(:items) ? phase.items : (phase.is_a?(Hash) ? phase[:items] : nil)
      item = Array(items).first
      return if item.blank?

      price = item.respond_to?(:price) ? item.price : (item.is_a?(Hash) ? item[:price] : nil)
      return price.id if price.respond_to?(:id)

      price.to_s.presence
    end

    def update_metadata!(updates)
      metadata = normalized_metadata
      updates.each do |key, value|
        if value.nil?
          metadata.delete(key)
        else
          metadata[key] = value
        end
      end
      subscription.update!(metadata: metadata)
    end

    def parse_time(value)
      return value if value.is_a?(Time)
      return if value.blank?

      Time.zone.parse(value.to_s)
    rescue ArgumentError => e
      logger.warn("[Billing::ScheduledPlanChange] invalid time #{value.inspect}: #{e.class} - #{e.message}")
      nil
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
  end
end
