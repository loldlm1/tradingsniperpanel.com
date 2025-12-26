module Billing
  class ScheduledPlanChange
    METADATA_KEYS = %w[scheduled_plan_key scheduled_change_at scheduled_schedule_id].freeze

    def initialize(subscription:, logger: Rails.logger)
      @subscription = subscription
      @logger = logger
    end

    def fetch(current_price_key: nil)
      return nil unless subscription

      metadata = normalized_metadata
      price_key = metadata["scheduled_plan_key"]
      return nil if price_key.blank?

      if current_price_key.present? && price_key == current_price_key
        clear!
        return nil
      end

      effective_at = parse_time(metadata["scheduled_change_at"])
      if effective_at.present? && effective_at <= Time.current && current_price_key.present? && price_key == current_price_key
        clear!
        return nil
      end

      {
        price_key: price_key,
        effective_at: effective_at,
        schedule_id: metadata["scheduled_schedule_id"]
      }
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

    def normalized_metadata
      (subscription.metadata || {}).to_h.stringify_keys
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
  end
end
