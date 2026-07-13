require "set"

module Billing
  class LegacySubscriptionMigrator
    MIGRATION_KEY = "pandora_catalog_v1".freeze
    METADATA_KEYS = {
      migration: "pandora_catalog_migration",
      target_plan: "pandora_catalog_target_plan_key",
      target_price: "pandora_catalog_target_price_id",
      schedule: "pandora_catalog_schedule_id",
      effective_at: "pandora_catalog_effective_at",
      scheduled_at: "pandora_catalog_scheduled_at"
    }.freeze

    Result = Struct.new(:scheduled, :verified, :current, :canceling, keyword_init: true)

    def initialize(logger: Rails.logger, schedule_factory: nil, subscription_scope: nil, now: Time.current)
      @logger = logger
      @schedule_factory = schedule_factory || ->(subscription) {
        Billing::StripeSubscriptionSchedule.new(subscription: subscription, logger: logger)
      }
      @subscription_scope = subscription_scope
      @now = now
    end

    def call
      counts = { scheduled: 0, verified: 0, current: 0, canceling: 0 }

      legacy_scope.find_each do |subscription|
        if current_price_ids.include?(subscription.processor_plan)
          counts[:current] += 1
          next
        end
        unless renewable?(subscription)
          counts[:canceling] += 1
          next
        end

        target_plan = target_plan_for(subscription)
        transition = schedule_for(subscription).schedule_catalog_transition(
          target_price_id: target_plan.stripe_price_id,
          target_plan_key: target_plan.key,
          effective_at: subscription.current_period_end,
          migration_key: MIGRATION_KEY
        )
        persist_metadata!(subscription:, target_plan:, schedule_id: transition.schedule.id)
        counts[transition.created ? :scheduled : :verified] += 1
      end

      Result.new(**counts)
    end

    def verify!
      legacy_scope.find_each do |subscription|
        next if current_price_ids.include?(subscription.processor_plan)
        next unless renewable?(subscription)

        target_plan = target_plan_for(subscription)
        metadata = normalized_metadata(subscription)
        schedule_id = metadata[METADATA_KEYS.fetch(:schedule)]
        unless migration_metadata_matches?(metadata, subscription:, target_plan:)
          raise "Pandora migration metadata is incomplete for subscription #{subscription.processor_id}"
        end

        verified = schedule_for(subscription).verify_catalog_transition(
          schedule_id: schedule_id,
          target_price_id: target_plan.stripe_price_id,
          target_plan_key: target_plan.key,
          effective_at: subscription.current_period_end,
          migration_key: MIGRATION_KEY
        )
        raise "Pandora schedule verification failed for subscription #{subscription.processor_id}" unless verified
      end

      true
    end

    private

    attr_reader :logger, :schedule_factory, :subscription_scope, :now

    def legacy_scope
      (subscription_scope || Pay::Subscription.active.stripe).order(:id)
    end

    def current_plans
      @current_plans ||= BillingPlan.purchasable.index_by(&:key)
    end

    def current_price_ids
      @current_price_ids ||= current_plans.values.map(&:stripe_price_id).to_set
    end

    def target_plan_for(subscription)
      interval, interval_count = source_interval(subscription.processor_plan)
      key = case [ interval, interval_count ]
      when [ "month", 1 ]
              Billing::PandoraPricing::MONTHLY_KEY
      when [ "year", 1 ]
              Billing::PandoraPricing::ANNUAL_KEY
      end
      target = current_plans[key]
      return target if target

      raise "Unsupported legacy interval for subscription #{subscription.processor_id}"
    end

    def source_interval(price_id)
      history = BillingPlanPrice.for_price_id(price_id)
      return [ history.interval, history.interval_count.to_i ] if history&.interval.present?

      plan = BillingPlan.for_price_id(price_id)
      return [ plan.interval, plan.interval_count.to_i ] if plan&.subscription?

      Stripe.api_key = ENV["STRIPE_PRIVATE_KEY"]
      price = Stripe::Price.retrieve(price_id)
      recurring = value_for(price, :recurring)
      [ value_for(recurring, :interval).to_s, value_for(recurring, :interval_count).to_i ]
    end

    def renewable?(subscription)
      return false if subscription.current_period_end.blank?
      return true if subscription.ends_at.blank?

      subscription.ends_at > subscription.current_period_end + 1.second
    end

    def persist_metadata!(subscription:, target_plan:, schedule_id:)
      subscription.with_lock do
        metadata = normalized_metadata(subscription)
        metadata.merge!(
          METADATA_KEYS.fetch(:migration) => MIGRATION_KEY,
          METADATA_KEYS.fetch(:target_plan) => target_plan.key,
          METADATA_KEYS.fetch(:target_price) => target_plan.stripe_price_id,
          METADATA_KEYS.fetch(:schedule) => schedule_id,
          METADATA_KEYS.fetch(:effective_at) => subscription.current_period_end.iso8601,
          METADATA_KEYS.fetch(:scheduled_at) => metadata[METADATA_KEYS.fetch(:scheduled_at)] || now.iso8601,
          "scheduled_plan_key" => target_plan.key,
          "scheduled_change_at" => subscription.current_period_end.iso8601,
          "scheduled_schedule_id" => schedule_id
        )
        subscription.update!(metadata: metadata)
      end
    end

    def migration_metadata_matches?(metadata, subscription:, target_plan:)
      metadata[METADATA_KEYS.fetch(:migration)] == MIGRATION_KEY &&
        metadata[METADATA_KEYS.fetch(:target_plan)] == target_plan.key &&
        metadata[METADATA_KEYS.fetch(:target_price)] == target_plan.stripe_price_id &&
        metadata[METADATA_KEYS.fetch(:schedule)].present? &&
        parse_time(metadata[METADATA_KEYS.fetch(:effective_at)])&.to_i == subscription.current_period_end.to_i
    end

    def normalized_metadata(subscription)
      (subscription.metadata || {}).to_h.stringify_keys
    end

    def schedule_for(subscription)
      schedule_factory.call(subscription)
    end

    def parse_time(value)
      Time.zone.parse(value.to_s) if value.present?
    rescue ArgumentError
      nil
    end

    def value_for(source, key)
      return if source.blank?
      return source.public_send(key) if source.respond_to?(key)
      return source[key] || source[key.to_s] if source.is_a?(Hash)

      nil
    end
  end
end
