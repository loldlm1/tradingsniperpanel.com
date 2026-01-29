module Admin
  class BillingPlanUpsert
    Result = Struct.new(:plan, :errors, keyword_init: true) do
      def ok?
        errors.blank?
      end
    end

    def initialize(plan: nil, attributes: {}, logger: Rails.logger)
      @plan = plan
      @attributes = normalize_attributes(attributes)
      @logger = logger
    end

    def call
      attrs = attributes_with_key

      if stripe_configured?
        result = Billing::PlanCreator.new(attrs, logger: logger).call
        return Result.new(plan: result.plan, errors: [])
      end

      plan = resolve_plan(attrs)
      plan.assign_attributes(attrs)
      plan.save!
      Result.new(plan: plan, errors: [])
    rescue ActiveRecord::RecordInvalid => e
      record = e.record
      errors = record&.errors&.full_messages
      errors = [e.message] if errors.blank?
      Result.new(plan: record || plan, errors: errors)
    rescue StandardError => e
      logger.error("[Admin::BillingPlanUpsert] failed key=#{attrs&.dig(:key)}: #{e.class} - #{e.message}")
      fallback_plan = plan || BillingPlan.new(attrs || {})
      fallback_plan.errors.add(:base, e.message) if fallback_plan.respond_to?(:errors)
      Result.new(plan: fallback_plan, errors: [e.message])
    end

    private

    attr_reader :plan, :attributes, :logger

    def stripe_configured?
      ENV["STRIPE_PRIVATE_KEY"].present?
    end

    def attributes_with_key
      attrs = attributes.dup
      attrs[:key] = plan.key if attrs[:key].blank? && plan&.key.present?
      attrs
    end

    def resolve_plan(attrs)
      return plan if plan

      BillingPlan.find_or_initialize_by(key: attrs.fetch(:key))
    end

    def normalize_attributes(value)
      attrs = value.to_h.symbolize_keys

      attrs[:amount_cents] = integerize(attrs[:amount_cents]) if attrs.key?(:amount_cents)
      attrs[:interval_count] = integerize(attrs[:interval_count]) if attrs.key?(:interval_count)
      attrs[:sort_order] = integerize(attrs[:sort_order]) if attrs.key?(:sort_order)
      attrs[:currency] = attrs[:currency].to_s.downcase.presence if attrs.key?(:currency)
      attrs[:metadata] = parse_metadata(attrs[:metadata]) if attrs.key?(:metadata)

      attrs.compact
    end

    def integerize(value)
      return nil if value.blank?

      value.to_i
    end

    def parse_metadata(value)
      return {} if value.blank?
      return value if value.is_a?(Hash)

      JSON.parse(value)
    rescue JSON::ParserError
      raise ArgumentError, I18n.t("active_admin.billing_plans.errors.metadata_invalid")
    end
  end
end
