require "digest"

module Billing
  class PlanCreator
    Result = Struct.new(:plan, :product, :price, keyword_init: true)

    def initialize(attributes, logger: Rails.logger)
      @attributes = attributes.to_h.symbolize_keys
      @logger = logger
    end

    def call
      ensure_stripe_key!

      plan = BillingPlan.find_or_initialize_by(key: attributes.fetch(:key))
      assign_plan_attributes(plan)

      product = find_or_create_product(plan)
      price = ensure_price(plan, product)

      plan.stripe_product_id = product.id
      plan.stripe_price_id = price.id
      plan.save!

      Result.new(plan: plan, product: product, price: price)
    rescue StandardError => e
      logger.error("[Billing::PlanCreator] failed key=#{attributes[:key]}: #{e.class} - #{e.message}")
      raise
    end

    private

    attr_reader :attributes, :logger

    def assign_plan_attributes(plan)
      plan.assign_attributes(attributes.slice(
        :name,
        :description,
        :kind,
        :tier,
        :interval,
        :interval_count,
        :amount_cents,
        :currency,
        :active,
        :sort_order,
        :metadata
      ))
      plan.stripe_product_id = attributes[:stripe_product_id] if attributes[:stripe_product_id].present?
      plan.stripe_price_id = attributes[:stripe_price_id] if attributes[:stripe_price_id].present?
      plan.interval_count = 1 if plan.subscription? && plan.interval_count.blank?
      plan.currency = plan.currency.to_s.downcase.presence || "usd"
    end

    def find_or_create_product(plan)
      product = retrieve_product(attributes[:stripe_product_id] || plan.stripe_product_id)
      product ||= find_product_by_name(plan.name)

      if product
        update_product_if_needed(product, plan)
        return product
      end

      Stripe.api_key = ENV["STRIPE_PRIVATE_KEY"]
      params = product_create_params(plan)
      Stripe::Product.create(
        params,
        { idempotency_key: idempotency_key_for("product", plan.key, params) }
      )
    end

    def retrieve_product(product_id)
      return if product_id.blank?

      Stripe.api_key = ENV["STRIPE_PRIVATE_KEY"]
      Stripe::Product.retrieve(product_id)
    rescue StandardError => e
      raise unless missing_resource_error?(e, resource: :product)

      logger.warn(
        "[Billing::PlanCreator] missing Stripe product key=#{attributes[:key]} product_id=#{product_id}; rebuilding mapping"
      )
      nil
    end

    def find_product_by_name(name)
      return if name.blank?

      Stripe.api_key = ENV["STRIPE_PRIVATE_KEY"]
      if Stripe::Product.respond_to?(:search)
        results = Stripe::Product.search(query: %(name:"#{name}"), limit: 1)
        return results.data.first if results.respond_to?(:data)
      end

      Stripe::Product.list(limit: 100).data.find { |product| product.name == name }
    end

    def update_product_if_needed(product, plan)
      updates = {}
      updates[:name] = plan.name if plan.name.present? && product.name != plan.name
      updates[:description] = plan.description if plan.description.to_s != product.description.to_s
      updates[:metadata] = product_metadata(plan) if product.metadata.to_h != product_metadata(plan)
      return product if updates.blank?

      Stripe.api_key = ENV["STRIPE_PRIVATE_KEY"]
      Stripe::Product.update(product.id, updates)
    end

    def ensure_price(plan, product)
      existing = retrieve_price(plan.stripe_price_id)
      return existing if price_matches?(existing, plan)

      new_price = create_price(plan, product.id)
      deactivate_price(existing) if existing.present?
      new_price
    end

    def retrieve_price(price_id)
      return if price_id.blank?

      Stripe.api_key = ENV["STRIPE_PRIVATE_KEY"]
      Stripe::Price.retrieve(price_id)
    rescue StandardError => e
      raise unless missing_resource_error?(e, resource: :price)

      logger.warn(
        "[Billing::PlanCreator] missing Stripe price key=#{attributes[:key]} price_id=#{price_id}; rebuilding mapping"
      )
      nil
    end

    def create_price(plan, product_id)
      Stripe.api_key = ENV["STRIPE_PRIVATE_KEY"]
      params = price_create_params(plan, product_id: product_id)
      Stripe::Price.create(
        params,
        { idempotency_key: idempotency_key_for("price", plan.key, params) }
      )
    end

    def price_matches?(price, plan)
      return false if price.blank?
      return false unless price.respond_to?(:active) ? price.active : true
      return false if price.unit_amount.to_i != plan.amount_cents.to_i
      return false if price.currency.to_s.downcase != plan.currency.to_s.downcase

      recurring = price.respond_to?(:recurring) ? price.recurring : nil
      if plan.subscription?
        return false if recurring.blank?
        return false if recurring.interval.to_s != plan.interval.to_s
        return false if recurring.interval_count.to_i != plan.interval_count.to_i
      else
        return false if recurring.present?
      end

      true
    end

    def deactivate_price(price)
      return unless price.respond_to?(:id)

      Stripe.api_key = ENV["STRIPE_PRIVATE_KEY"]
      Stripe::Price.update(price.id, active: false)
    end

    def product_metadata(plan)
      (plan.metadata || {}).to_h.merge("billing_plan_key" => plan.key)
    end

    def product_create_params(plan)
      {
        name: plan.name,
        description: plan.description,
        metadata: product_metadata(plan)
      }
    end

    def price_create_params(plan, product_id:)
      params = {
        product: product_id,
        currency: plan.currency,
        unit_amount: plan.amount_cents
      }

      if plan.subscription?
        params[:recurring] = {
          interval: plan.interval,
          interval_count: plan.interval_count
        }
      end

      params
    end

    def idempotency_key_for(resource_type, plan_key, params)
      normalized = normalize_for_digest(params)
      digest = Digest::SHA256.hexdigest(normalized.to_json)
      "#{resource_type}:#{plan_key}:#{digest.first(24)}"
    end

    def normalize_for_digest(value)
      case value
      when Hash
        value.to_h.each_with_object({}) do |(key, nested_value), memo|
          memo[key.to_s] = normalize_for_digest(nested_value)
        end.sort.to_h
      when Array
        value.map { |item| normalize_for_digest(item) }
      else
        value
      end
    end

    def ensure_stripe_key!
      return if ENV["STRIPE_PRIVATE_KEY"].present?

      raise ArgumentError, "STRIPE_PRIVATE_KEY is not set"
    end

    def missing_resource_error?(error, resource:)
      return false unless defined?(Stripe::InvalidRequestError)
      return false unless error.is_a?(Stripe::InvalidRequestError)
      return true if error.respond_to?(:code) && error.code.to_s == "resource_missing"

      message = error.message.to_s
      case resource
      when :product
        message.include?("No such product")
      when :price
        message.include?("No such price")
      else
        message.include?("No such")
      end
    end
  end
end
