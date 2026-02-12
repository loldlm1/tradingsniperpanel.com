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
        OpenStruct.new(data: [])
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
        attr_accessor :prices, :counter
      end

      def self.retrieve(id)
        raise Stripe::InvalidRequestError.new("No such price: '#{id}'", code: "resource_missing") if id.start_with?("seed_price_")

        prices[id]
      end

      def self.create(params, _opts = {})
        self.counter = counter.to_i + 1
        id = "price_live_#{counter}"
        price = OpenStruct.new(
          id: id,
          unit_amount: params[:unit_amount],
          currency: params[:currency],
          recurring: params[:recurring],
          active: true
        )
        prices[id] = price
        price
      end

      def self.update(id, params)
        price = prices[id]
        return unless price

        params.each do |key, value|
          setter = "#{key}="
          price.public_send(setter, value) if price.respond_to?(setter)
        end
        price
      end
    end

    product_class.products = products
    price_class.prices = prices

    stub_const("Stripe::Product", product_class)
    stub_const("Stripe::Price", price_class)
  end
end
