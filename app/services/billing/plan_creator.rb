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
      previous_snapshot = price_snapshot_for_plan(plan)
      assign_plan_attributes(plan)
      raise ActiveRecord::RecordInvalid, plan unless plan.valid?

      product = find_or_create_product(
        plan,
        candidate_ids: [ attributes[:stripe_product_id], previous_snapshot&.dig(:stripe_product_id) ]
      )
      price = ensure_price(
        plan,
        product,
        candidate_ids: [
          attributes[:stripe_price_id],
          previous_snapshot&.dig(:stripe_price_id),
          current_history_price_id(plan)
        ]
      )

      persisted_plan = persist_price_history!(
        plan: plan,
        product: product,
        price: price,
        previous_snapshot: previous_snapshot
      )
      retire_superseded_remote_prices!(persisted_plan, current_price_id: price.id)

      Result.new(plan: persisted_plan, product: product, price: price)
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
      plan.interval_count = 1 if plan.subscription? && plan.interval_count.blank?
      plan.currency = plan.currency.to_s.downcase.presence || "usd"
    end

    def find_or_create_product(plan, candidate_ids:)
      Array(candidate_ids).compact_blank.uniq.each do |product_id|
        product = retrieve_product(product_id)
        next unless product

        update_product_if_needed(product, plan)
        return product
      end

      product = find_product_by_name(plan.name)
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
        product = results.data.first if results.respond_to?(:data)
        return product if product
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

    def ensure_price(plan, product, candidate_ids:)
      Array(candidate_ids).compact_blank.uniq.each do |price_id|
        existing = retrieve_price(price_id)
        return existing if price_matches?(existing, plan)
      end

      create_price(plan, product.id)
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
      return false if value_for(price, :active) == false
      return false if value_for(price, :unit_amount).to_i != plan.amount_cents.to_i
      return false if value_for(price, :currency).to_s.downcase != plan.currency.to_s.downcase

      recurring = value_for(price, :recurring)
      if plan.subscription?
        return false if recurring.blank?
        return false if value_for(recurring, :interval).to_s != plan.interval.to_s
        return false if value_for(recurring, :interval_count).to_i != plan.interval_count.to_i
      else
        return false if recurring.present?
      end

      true
    end

    def persist_price_history!(plan:, product:, price:, previous_snapshot:)
      now = Time.current

      BillingPlan.transaction do
        persisted_plan = plan.persisted? ? BillingPlan.lock.find(plan.id) : BillingPlan.new(key: plan.key)
        assign_plan_attributes(persisted_plan)
        persisted_plan.stripe_product_id = product.id
        persisted_plan.stripe_price_id = price.id
        persisted_plan.save!

        current_record = upsert_price_record!(billing_plan: persisted_plan, price: price)
        persisted_plan.billing_plan_prices.current.where.not(id: current_record.id).lock.each do |record|
          record.update!(current: false, retired_at: record.retired_at || now)
        end
        preserve_previous_snapshot!(
          billing_plan: persisted_plan,
          snapshot: previous_snapshot,
          current_price_id: price.id,
          retired_at: now
        )
        current_record.update!(active: true, current: true, retired_at: nil)

        persisted_plan
      end
    end

    def upsert_price_record!(billing_plan:, price:)
      record = BillingPlanPrice.find_or_initialize_by(stripe_price_id: price.id)
      ensure_price_ownership!(record, billing_plan)
      was_current = record.current?
      record.assign_attributes(price_history_attributes(billing_plan, price))
      record.billing_plan = billing_plan
      record.current = was_current
      record.save!
      record
    end

    def preserve_previous_snapshot!(billing_plan:, snapshot:, current_price_id:, retired_at:)
      return if snapshot.blank?
      return if snapshot[:stripe_price_id] == current_price_id

      record = BillingPlanPrice.find_or_initialize_by(stripe_price_id: snapshot.fetch(:stripe_price_id))
      ensure_price_ownership!(record, billing_plan)
      unless record.persisted?
        record.assign_attributes(snapshot.slice(:amount_cents, :currency, :interval, :interval_count, :active, :metadata))
        record.billing_plan = billing_plan
      end
      record.current = false
      record.retired_at ||= retired_at
      record.save!
    end

    def ensure_price_ownership!(record, billing_plan)
      return if record.billing_plan_id.blank? || record.billing_plan_id == billing_plan.id

      raise ActiveRecord::RecordInvalid, record
    end

    def retire_superseded_remote_prices!(plan, current_price_id:)
      plan.billing_plan_prices.retired.active
          .where.not(stripe_price_id: current_price_id)
          .order(:id)
          .each do |history|
        remote_price = retrieve_price(history.stripe_price_id)
        deactivate_price(remote_price) if remote_price && value_for(remote_price, :active) != false
        history.update!(active: false)
      end
    end

    def deactivate_price(price)
      return unless price.respond_to?(:id)

      Stripe.api_key = ENV["STRIPE_PRIVATE_KEY"]
      Stripe::Price.update(price.id, active: false)
    end

    def price_snapshot_for_plan(plan)
      return unless plan.persisted? && plan.stripe_price_id.present?

      {
        stripe_product_id: plan.stripe_product_id,
        stripe_price_id: plan.stripe_price_id,
        amount_cents: plan.amount_cents,
        currency: plan.currency.to_s.downcase,
        interval: plan.subscription? ? plan.interval : nil,
        interval_count: plan.subscription? ? plan.interval_count : nil,
        active: true,
        metadata: { "billing_plan_key" => plan.key }
      }
    end

    def current_history_price_id(plan)
      return unless plan.persisted? && BillingPlanPrice.table_exists?

      plan.current_billing_plan_price&.stripe_price_id
    end

    def price_history_attributes(plan, price)
      recurring = value_for(price, :recurring)
      {
        amount_cents: value_for(price, :unit_amount).to_i,
        currency: value_for(price, :currency).to_s.downcase,
        interval: recurring.present? ? value_for(recurring, :interval).to_s : nil,
        interval_count: recurring.present? ? value_for(recurring, :interval_count).to_i : nil,
        active: value_for(price, :active) != false,
        metadata: { "billing_plan_key" => plan.key }
      }
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
        unit_amount: plan.amount_cents,
        metadata: { "billing_plan_key" => plan.key }
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

    def value_for(source, key)
      return if source.blank?

      if source.respond_to?(key)
        source.public_send(key)
      elsif source.is_a?(Hash)
        source[key.to_s] || source[key.to_sym]
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
