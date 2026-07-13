require "rails_helper"
require "ostruct"

RSpec.describe Billing::PlanCreator do
  around do |example|
    original_key = ENV["STRIPE_PRIVATE_KEY"]
    ENV["STRIPE_PRIVATE_KEY"] = "seed_test_key"
    example.run
  ensure
    ENV["STRIPE_PRIVATE_KEY"] = original_key
  end

  before do
    stub_stripe
  end

  it "recovers from stale Stripe product and price IDs" do
    plan = create(
      :billing_plan,
      :one_time,
      key: "marketplace_ea_sniper_panel",
      name: "Sniper Panel EA",
      description: "Legacy plan",
      amount_cents: 29_900,
      currency: "usd",
      stripe_product_id: "seed_prod_ea_sniper_panel",
      stripe_price_id: "seed_price_ea_sniper_panel"
    )

    result = described_class.new(
      {
        key: plan.key,
        name: "Sniper Panel EA",
        description: "Risk-first panel EA with precision execution tools.",
        kind: "one_time",
        amount_cents: 29_900,
        currency: "usd",
        active: true,
        sort_order: 4,
        metadata: { "marketplace_slug" => "ea_sniper_panel" }
      }
    ).call

    expect(result.plan.id).to eq(plan.id)
    expect(plan.reload.stripe_product_id).to eq("prod_live_1")
    expect(plan.reload.stripe_price_id).to eq("price_live_1")
    expect(Stripe::Product.counter).to eq(1)
    expect(Stripe::Price.counter).to eq(1)
  end

  it "re-raises non-recoverable Stripe invalid request errors" do
    plan = create(
      :billing_plan,
      :one_time,
      key: "marketplace_broken",
      name: "Broken Product",
      amount_cents: 9_900,
      currency: "usd",
      stripe_product_id: "prod_nonrecoverable"
    )

    expect do
      described_class.new(
        {
          key: plan.key,
          name: plan.name,
          kind: "one_time",
          amount_cents: plan.amount_cents,
          currency: plan.currency,
          active: true,
          sort_order: 1
        }
      ).call
    end.to raise_error(Stripe::InvalidRequestError, /Invalid product identifier/)
  end

  it "uses a distinct price idempotency key when price payload parameters change" do
    plan = create(
      :billing_plan,
      key: "pro_monthly",
      tier: "pro",
      interval: "month",
      interval_count: 1,
      name: "Pro Monthly",
      amount_cents: 6_000,
      currency: "usd",
      stripe_product_id: "seed_prod_pro_monthly",
      stripe_price_id: "seed_price_pro_monthly"
    )

    attrs = {
      key: plan.key,
      name: plan.name,
      description: "Pro monthly plan",
      kind: "subscription",
      tier: plan.tier,
      interval: plan.interval,
      interval_count: plan.interval_count,
      amount_cents: plan.amount_cents,
      currency: plan.currency,
      active: true,
      sort_order: 3
    }

    expect { described_class.new(attrs).call }.not_to raise_error
    first_product_id = plan.reload.stripe_product_id
    first_price_id = plan.reload.stripe_price_id

    # Simulate remapping after stale Stripe IDs in a subsequent rerun.
    plan.update!(
      stripe_product_id: "seed_prod_pro_monthly_again",
      stripe_price_id: "seed_price_pro_monthly_again"
    )

    expect { described_class.new(attrs.merge(amount_cents: 7_000)).call }.not_to raise_error
    expect(plan.reload.stripe_product_id).to eq(first_product_id)
    expect(plan.reload.stripe_price_id).not_to eq(first_price_id)
    expect(Stripe::Price.idempotency_keys.uniq.size).to eq(2)
  end

  it "preserves the retired price snapshot when the amount changes" do
    attrs = subscription_attributes(key: "pandora_pro_monthly", amount_cents: 7_900)
    first = described_class.new(attrs).call
    old_price_id = first.price.id

    second = described_class.new(attrs.merge(amount_cents: 8_900)).call

    old_history = BillingPlanPrice.find_by!(stripe_price_id: old_price_id)
    new_history = BillingPlanPrice.find_by!(stripe_price_id: second.price.id)
    expect(first.plan.reload.stripe_price_id).to eq(second.price.id)
    expect(old_history).not_to be_current
    expect(old_history).not_to be_active
    expect(old_history.retired_at).to be_present
    expect(old_history.amount_cents).to eq(7_900)
    expect(new_history).to be_current
    expect(new_history.amount_cents).to eq(8_900)
    expect(BillingPlan.for_price_id(old_price_id)).to eq(first.plan)
  end

  it "converges on the same current price when retried" do
    attrs = subscription_attributes(key: "pandora_pro_annual", amount_cents: 61_620, interval: "year")

    first = described_class.new(attrs).call
    second = described_class.new(attrs).call

    expect(second.price.id).to eq(first.price.id)
    expect(Stripe::Price.counter).to eq(1)
    expect(first.plan.billing_plan_prices.reload.count).to eq(1)
    expect(first.plan.billing_plan_prices.current.first.stripe_price_id).to eq(first.price.id)
  end

  it "reuses the Stripe price when local persistence fails and is retried" do
    attrs = subscription_attributes(key: "pandora_pro_monthly", amount_cents: 7_900)
    failures = 0
    allow_any_instance_of(BillingPlanPrice).to receive(:save!).and_wrap_original do |method, *args|
      if failures.zero?
        failures += 1
        raise ActiveRecord::RecordInvalid, method.receiver
      end

      method.call(*args)
    end

    expect { described_class.new(attrs).call }.to raise_error(ActiveRecord::RecordInvalid)
    expect(BillingPlan.find_by(key: attrs[:key])).to be_nil

    result = described_class.new(attrs).call

    expect(result.plan).to be_persisted
    expect(Stripe::Product.counter).to eq(1)
    expect(Stripe::Price.counter).to eq(1)
    expect(result.plan.billing_plan_prices.current.first.stripe_price_id).to eq(result.price.id)
  end

  it "keeps the prior current mapping when Stripe price creation fails" do
    plan = create_remote_subscription_plan(amount_cents: 7_900)
    previous = create(
      :billing_plan_price,
      billing_plan: plan,
      stripe_price_id: plan.stripe_price_id,
      amount_cents: plan.amount_cents,
      current: true
    )
    Stripe::Price.fail_next_create = true

    expect do
      described_class.new(subscription_attributes(key: plan.key, amount_cents: 8_900)).call
    end.to raise_error(StandardError, "Stripe price creation failed")

    expect(plan.reload.amount_cents).to eq(7_900)
    expect(plan.stripe_price_id).to eq(previous.stripe_price_id)
    expect(previous.reload).to be_current
    expect(previous).to be_active
  end

  it "retries remote retirement without creating another current price" do
    plan = create_remote_subscription_plan(amount_cents: 7_900)
    old_history = create(
      :billing_plan_price,
      billing_plan: plan,
      stripe_price_id: plan.stripe_price_id,
      amount_cents: plan.amount_cents,
      current: true
    )
    Stripe::Price.fail_updates_for = [ old_history.stripe_price_id ]
    attrs = subscription_attributes(key: plan.key, amount_cents: 8_900)

    expect { described_class.new(attrs).call }.to raise_error(StandardError, "Stripe price retirement failed")

    new_price_id = plan.reload.stripe_price_id
    expect(new_price_id).not_to eq(old_history.stripe_price_id)
    expect(old_history.reload).not_to be_current
    expect(old_history).to be_active
    expect(BillingPlanPrice.find_by!(stripe_price_id: new_price_id)).to be_current

    Stripe::Price.fail_updates_for = []
    result = described_class.new(attrs).call

    expect(result.price.id).to eq(new_price_id)
    expect(Stripe::Price.counter).to eq(1)
    expect(old_history.reload).not_to be_active
  end

  def subscription_attributes(key:, amount_cents:, interval: "month")
    {
      key: key,
      name: key.humanize,
      description: "Pandora subscription",
      kind: "subscription",
      tier: key.delete_suffix("_monthly").delete_suffix("_annual"),
      interval: interval,
      interval_count: 1,
      amount_cents: amount_cents,
      currency: "usd",
      active: true,
      sort_order: 1
    }
  end

  def create_remote_subscription_plan(amount_cents:)
    product = OpenStruct.new(
      id: "prod_existing",
      name: "Pandora Pro Monthly",
      description: "Pandora subscription",
      metadata: { "billing_plan_key" => "pandora_pro_monthly" }
    )
    price = OpenStruct.new(
      id: "price_existing",
      product: product.id,
      unit_amount: amount_cents,
      currency: "usd",
      recurring: { interval: "month", interval_count: 1 },
      metadata: { "billing_plan_key" => "pandora_pro_monthly" },
      active: true
    )
    Stripe::Product.products[product.id] = product
    Stripe::Price.prices[price.id] = price

    create(
      :billing_plan,
      key: "pandora_pro_monthly",
      name: product.name,
      description: product.description,
      tier: "pandora_pro",
      interval: "month",
      interval_count: 1,
      amount_cents: amount_cents,
      stripe_product_id: product.id,
      stripe_price_id: price.id
    )
  end

  def stub_stripe
    stripe_module = Module.new
    stripe_module.singleton_class.attr_accessor :api_key
    stub_const("Stripe", stripe_module)

    invalid_request_error = Class.new(StandardError) do
      attr_reader :code

      def initialize(message, code: nil)
        @code = code
        super(message)
      end
    end
    stub_const("Stripe::InvalidRequestError", invalid_request_error)
    stub_const("Stripe::IdempotencyError", Class.new(StandardError))

    products = {}
    prices = {}

    product_class = Class.new do
      class << self
        attr_accessor :products, :counter
      end

      def self.retrieve(id)
        raise Stripe::InvalidRequestError.new("No such product: '#{id}'", code: "resource_missing") if id.start_with?("seed_prod_")
        raise Stripe::InvalidRequestError.new("Invalid product identifier", code: "invalid_request") if id == "prod_nonrecoverable"

        products[id]
      end

      def self.search(query:, limit:)
        OpenStruct.new(data: [])
      end

      def self.list(limit:)
        OpenStruct.new(data: products.values)
      end

      def self.create(params, _opts = {})
        self.counter = counter.to_i + 1
        id = "prod_live_#{counter}"
        product = OpenStruct.new(
          id: id,
          name: params[:name],
          description: params[:description],
          metadata: params[:metadata] || {}
        )
        products[id] = product
        product
      end

      def self.update(id, params)
        product = products[id]
        return unless product

        params.each do |key, value|
          setter = "#{key}="
          product.public_send(setter, value) if product.respond_to?(setter)
        end
        product
      end
    end

    price_class = Class.new do
      class << self
        attr_accessor :prices, :counter, :idempotent_requests, :idempotent_price_ids,
                      :idempotency_keys, :fail_next_create, :fail_updates_for
      end

      def self.retrieve(id)
        raise Stripe::InvalidRequestError.new("No such price: '#{id}'", code: "resource_missing") if id.start_with?("seed_price_")

        prices[id]
      end

      def self.create(params, opts = {})
        if fail_next_create
          self.fail_next_create = false
          raise StandardError, "Stripe price creation failed"
        end

        idempotency_key = opts[:idempotency_key].to_s
        if idempotency_key.present?
          normalized_params = normalize_params(params)
          existing_params = idempotent_requests[idempotency_key]
          if existing_params.present? && existing_params != normalized_params
            raise Stripe::IdempotencyError,
              "Keys for idempotent requests can only be used with the same parameters they were first used with. Try using a key other than '#{idempotency_key}' if you meant to execute a different request."
          end

          idempotent_requests[idempotency_key] = normalized_params
          idempotency_keys << idempotency_key
          existing_price_id = idempotent_price_ids[idempotency_key]
          return prices.fetch(existing_price_id) if existing_price_id.present?
        end

        self.counter = counter.to_i + 1
        id = "price_live_#{counter}"
        price = OpenStruct.new(
          id: id,
          product: params[:product],
          unit_amount: params[:unit_amount],
          currency: params[:currency],
          recurring: params[:recurring],
          metadata: params[:metadata] || {},
          active: true
        )
        prices[id] = price
        idempotent_price_ids[idempotency_key] = id if idempotency_key.present?
        price
      end

      def self.update(id, params)
        raise StandardError, "Stripe price retirement failed" if Array(fail_updates_for).include?(id)

        price = prices[id]
        return unless price

        params.each do |key, value|
          setter = "#{key}="
          price.public_send(setter, value) if price.respond_to?(setter)
        end
        price
      end

      def self.normalize_params(value)
        case value
        when Hash
          value.to_h.each_with_object({}) do |(key, nested_value), memo|
            memo[key.to_s] = normalize_params(nested_value)
          end.sort.to_h
        when Array
          value.map { |item| normalize_params(item) }
        else
          value
        end
      end
    end

    product_class.products = products
    price_class.prices = prices
    price_class.idempotent_requests = {}
    price_class.idempotent_price_ids = {}
    price_class.idempotency_keys = []
    price_class.fail_next_create = false
    price_class.fail_updates_for = []

    stub_const("Stripe::Product", product_class)
    stub_const("Stripe::Price", price_class)
  end
end
