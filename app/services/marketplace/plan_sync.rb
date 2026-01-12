module Marketplace
  class PlanSync
    def initialize(product:, logger: Rails.logger)
      @product = product
      @logger = logger
    end

    def call
      plan = product.billing_plan
      return unless plan

      update_plan(plan)
      return plan unless ENV["STRIPE_PRIVATE_KEY"].present?

      Billing::PlanCreator.new(plan_attributes(plan), logger: logger).call
      plan
    rescue StandardError => e
      logger.error("[Marketplace::PlanSync] failed marketplace_product_id=#{product.id} billing_plan_id=#{plan&.id}: #{e.class} - #{e.message}")
      raise
    end

    private

    attr_reader :product, :logger

    def update_plan(plan)
      plan.assign_attributes(
        key: product.key,
        name: product.title_for(:en),
        description: product.summary_for(:en).presence || product.description_for(:en),
        kind: "one_time",
        tier: nil,
        interval: nil,
        interval_count: nil,
        active: product.active?,
        sort_order: product.sort_order,
        metadata: updated_metadata(plan.metadata)
      )
      plan.save!
    end

    def updated_metadata(existing)
      (existing || {}).to_h.merge(
        "marketplace_product_id" => product.id,
        "marketplace_product_key" => product.key,
        "marketplace_slug" => product.slug
      )
    end

    def plan_attributes(plan)
      {
        key: plan.key,
        name: plan.name,
        description: plan.description,
        kind: plan.kind,
        tier: plan.tier,
        interval: plan.interval,
        interval_count: plan.interval_count,
        amount_cents: plan.amount_cents,
        currency: plan.currency,
        active: plan.active,
        sort_order: plan.sort_order,
        metadata: plan.metadata
      }
    end
  end
end
