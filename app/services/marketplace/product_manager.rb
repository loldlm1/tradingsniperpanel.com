module Marketplace
  class ProductManager
    DEFAULT_CURRENCY = "usd"

    def initialize(logger: Rails.logger, stripe_required: true)
      @logger = logger
      @stripe_required = stripe_required
    end

    def upsert!(product_attributes:, plan_attributes:)
      attrs = normalize_hash(product_attributes)
      slug = attrs[:slug].to_s
      raise ArgumentError, "slug is required" if slug.blank?

      product = MarketplaceProduct.find_by(slug: slug)
      return create!(product_attributes: attrs, plan_attributes: plan_attributes) unless product

      update!(product: product, product_attributes: attrs, plan_attributes: plan_attributes)
    end

    def create!(product_attributes:, plan_attributes:)
      attrs = normalize_hash(product_attributes)
      product = MarketplaceProduct.new(attrs)
      product.valid?
      raise ActiveRecord::RecordInvalid, product if product.invalid?

      plan_attrs = build_plan_attributes(product, plan_attributes)
      plan = create_plan(plan_attrs)

      MarketplaceProduct.transaction do
        product.billing_plan = plan
        product.save!
        Marketplace::PlanSync.new(product: product, logger: logger, sync_stripe: stripe_required).call
      end

      product
    rescue StandardError => e
      logger.error("[Marketplace::ProductManager] create failed slug=#{attrs[:slug]}: #{e.class} - #{e.message}")
      raise
    end

    def update!(product:, product_attributes:, plan_attributes:)
      attrs = normalize_hash(product_attributes)
      product.assign_attributes(attrs.except(:slug, :key))
      plan = product.billing_plan
      raise ArgumentError, "Marketplace product is missing a billing plan" unless plan

      apply_plan_attributes(plan, plan_attributes)
      product.valid?
      raise ActiveRecord::RecordInvalid, product if product.invalid?

      Marketplace::PlanSync.new(product: product, logger: logger, sync_stripe: stripe_required).call
      product.save!
      product
    rescue StandardError => e
      logger.error("[Marketplace::ProductManager] update failed marketplace_product_id=#{product.id}: #{e.class} - #{e.message}")
      raise
    end

    def archive!(product)
      product.assign_attributes(status: "draft")
      Marketplace::PlanSync.new(product: product, logger: logger, sync_stripe: stripe_required).call
      product.save!
      product
    rescue StandardError => e
      logger.error("[Marketplace::ProductManager] archive failed marketplace_product_id=#{product.id}: #{e.class} - #{e.message}")
      raise
    end

    private

    attr_reader :logger, :stripe_required

    def create_plan(plan_attrs)
      return Billing::PlanCreator.new(plan_attrs, logger: logger).call.plan if stripe_required

      BillingPlan.create!(plan_attrs)
    end

    def build_plan_attributes(product, plan_attributes)
      attrs = normalize_hash(plan_attributes)
      metadata = normalize_hash(attrs[:metadata] || {})
      metadata = metadata.merge(
        "marketplace_product_key" => product.key,
        "marketplace_slug" => product.slug
      )

      {
        key: product.key,
        name: product.title_for(:en),
        description: product.summary_for(:en).presence || product.description_for(:en),
        kind: "one_time",
        tier: nil,
        interval: nil,
        interval_count: nil,
        amount_cents: attrs.fetch(:amount_cents),
        currency: attrs.fetch(:currency, DEFAULT_CURRENCY),
        active: product.active?,
        sort_order: product.sort_order,
        metadata: metadata
      }
    end

    def apply_plan_attributes(plan, plan_attributes)
      attrs = normalize_hash(plan_attributes)
      return if attrs.empty?

      plan.amount_cents = attrs[:amount_cents] if attrs.key?(:amount_cents)
      plan.currency = attrs[:currency] if attrs.key?(:currency)
    end

    def normalize_hash(value)
      return {} if value.blank?

      value.to_h.symbolize_keys
    end
  end
end
