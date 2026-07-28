module Billing
  module SubscriptionCatalog
    Product = Struct.new(
      :catalog_key,
      :tier,
      :pricing,
      :description,
      :access_rank,
      :sort_order,
      :seat_cap,
      :vip_eligible,
      :ea_ids,
      keyword_init: true
    ) do
      def product_name
        pricing::PRODUCT_NAME
      end

      def currency
        pricing::CURRENCY
      end

      def plan_keys
        pricing::PLAN_KEYS
      end

      def plan_definitions
        pricing::PLAN_DEFINITIONS
      end
    end

    PRODUCTS = [
      Product.new(
        catalog_key: "chu_sniper_trailing",
        tier: Billing::ChuSniperPricing::TIER,
        pricing: Billing::ChuSniperPricing,
        description: "Chu Sniper Trailing recurring subscription.",
        access_rank: 1,
        sort_order: 1,
        seat_cap: 5,
        vip_eligible: true,
        ea_ids: [ "chu_sniper_trailing" ].freeze
      ).freeze,
      Product.new(
        catalog_key: "pandora_box",
        tier: Billing::PandoraPricing::TIER,
        pricing: Billing::PandoraPricing,
        description: "Pandora Box EA recurring subscription.",
        access_rank: 2,
        sort_order: 2,
        seat_cap: 5,
        vip_eligible: true,
        ea_ids: [ "pandora_box", "chu_sniper_trailing" ].freeze
      ).freeze
    ].freeze

    module_function

    def products
      PRODUCTS
    end

    def tiers
      PRODUCTS.map(&:tier)
    end

    def plan_keys
      PRODUCTS.flat_map(&:plan_keys)
    end

    def product_for_tier(tier)
      PRODUCTS.find { |product| product.tier == tier.to_s }
    end

    def product_for_catalog_key(catalog_key)
      PRODUCTS.find { |product| product.catalog_key == catalog_key.to_s }
    end

    def product_for_plan_key(plan_key)
      PRODUCTS.find { |product| product.plan_keys.include?(plan_key.to_s) }
    end

    def definition_for_key(plan_key)
      product = product_for_plan_key(plan_key)
      return unless product

      product.plan_definitions.fetch(plan_key.to_s).merge(product: product)
    end

    def parse_plan_key(plan_key)
      key = plan_key.to_s
      definition = definition_for_key(key)
      if definition
        product = definition.fetch(:product)
        return {
          key: key,
          tier: product.tier,
          interval_key: interval_key_for(definition),
          product: product,
          canonical: true
        }
      end

      interval_key = %w[monthly annual weekly daily].find { |candidate| key.end_with?("_#{candidate}") }
      tier = interval_key ? key.delete_suffix("_#{interval_key}") : nil
      { key: key, tier: tier.presence, interval_key: interval_key, product: nil, canonical: false }
    end

    def access_rank_for(tier)
      product_for_tier(tier)&.access_rank
    end

    def seat_cap_for(tier)
      product_for_tier(tier)&.seat_cap
    end

    def vip_eligible?(tier)
      product_for_tier(tier)&.vip_eligible == true
    end

    def ea_ids_for_tier(tier)
      Array(product_for_tier(tier)&.ea_ids)
    end

    def complete_products(plans)
      indexed = Array(plans).index_by(&:key)
      PRODUCTS.select do |product|
        product.plan_definitions.all? do |key, definition|
          plan_matches_definition?(indexed[key], product:, definition:)
        end
      end
    end

    def purchasable_scope
      base = BillingPlan.subscription.active
                        .where(currency: PRODUCTS.map(&:currency).uniq)
                        .where.not(stripe_price_id: [ nil, "" ])
      complete_keys = complete_products(base.to_a).flat_map(&:plan_keys)
      return BillingPlan.none if complete_keys.empty?

      base.where(key: complete_keys)
    end

    def plan_matches_definition?(plan, product:, definition:)
      return false unless plan

      plan.subscription? &&
        plan.active? &&
        plan.tier == product.tier &&
        plan.currency == product.currency &&
        plan.interval == definition.fetch(:interval) &&
        plan.interval_count.to_i == definition.fetch(:interval_count) &&
        plan.amount_cents.to_i == definition.fetch(:amount_cents) &&
        plan.stripe_product_id.present? &&
        plan.stripe_price_id.present?
    end

    def interval_key_for(definition)
      Billing::IntervalLabeler.interval_key(
        interval: definition.fetch(:interval),
        interval_count: definition.fetch(:interval_count)
      )
    end
    private_class_method :interval_key_for
  end
end
