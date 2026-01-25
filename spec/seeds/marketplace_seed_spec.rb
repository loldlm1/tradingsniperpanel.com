require "rails_helper"
require "ostruct"

RSpec.describe "Marketplace seeds" do
  around do |example|
    original_key = ENV["STRIPE_PRIVATE_KEY"]
    ENV["STRIPE_PRIVATE_KEY"] = "seed_test_key"
    example.run
  ensure
    ENV["STRIPE_PRIVATE_KEY"] = original_key
  end

  before do
    load Rails.root.join("db", "seeds", "shared.rb") unless defined?(Seeds::MarketplaceProducts)
    stub_stripe
    seed_prerequisites
    allow(Seeds::MarketplaceProducts).to receive(:attach_image)
  end

  it "creates marketplace products and billing plans with Stripe identifiers" do
    expect do
      Seeds::MarketplaceProducts.seed_products!
    end.to change(MarketplaceProduct, :count).by(10)

    products = MarketplaceProduct.order(:slug).to_a
    expect(products.map(&:slug)).to match_array(
      %w[
        asset_quick_start_guide
        asset_risk_checklist
        course_essentials
        course_intermediate_systems
        course_orderflow_lab
        course_trading_foundations
        ea_momentum_pulse
        ea_sniper_panel
        ea_starter_bundle
        pro_trader_bundle
      ]
    )

    products.each do |product|
      plan = product.billing_plan
      expect(plan).to be_present
      expect(plan.one_time?).to be(true)
      expect(plan.stripe_product_id).to be_present
      expect(plan.stripe_price_id).to be_present
    end

    expect(BillingPlan.where(key: products.map(&:key)).count).to eq(10)
    expect(BillingPlanEntitlement.count).to eq(5)
    expect(CoursePlanEntitlement.count).to eq(6)
    expect(AssetPlanEntitlement.count).to eq(7)

    expect do
      Seeds::MarketplaceProducts.seed_products!
    end.not_to change(MarketplaceProduct, :count)

    expect(Stripe::Product.counter.to_i).to eq(3)
    expect(Stripe::Price.counter.to_i).to eq(3)
  end

  def stub_stripe
    stub_const("Stripe", Module.new) unless defined?(Stripe)
    Stripe.singleton_class.attr_accessor :api_key unless Stripe.respond_to?(:api_key=)

    products = {}
    prices = {}

    product_class = Class.new do
      class << self
        attr_accessor :products, :counter
      end

      def self.retrieve(id)
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
        id = "prod_seed_#{counter}"
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
        prices[id]
      end

      def self.create(params, _opts = {})
        self.counter = counter.to_i + 1
        id = "price_seed_#{counter}"
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

  def seed_prerequisites
    ExpertAdvisor.find_or_create_by!(ea_id: "sniper_advanced_panel") do |ea|
      ea.name = "Sniper Advanced Panel"
      ea.description = "Seed"
      ea.ea_type = :ea_tool
      ea.allowed_subscription_tiers = []
      ea.tier_rank = 1
      ea.doc_guide_en = "Guide"
      ea.doc_guide_es = "Guia"
      ea.trial_enabled = true
    end

    ExpertAdvisor.find_or_create_by!(ea_id: "pandora_box") do |ea|
      ea.name = "Pandora Box"
      ea.description = "Seed"
      ea.ea_type = :ea_robot
      ea.allowed_subscription_tiers = []
      ea.tier_rank = 2
      ea.doc_guide_en = "Guide"
      ea.doc_guide_es = "Guia"
      ea.trial_enabled = true
    end

    ExpertAdvisor.find_or_create_by!(ea_id: "momentum_pulse_indicator") do |ea|
      ea.name = "Momentum Pulse Indicator"
      ea.description = "Seed"
      ea.ea_type = :indicator
      ea.allowed_subscription_tiers = []
      ea.tier_rank = 3
      ea.doc_guide_en = "Guide"
      ea.doc_guide_es = "Guia"
      ea.trial_enabled = false
    end

    Course.find_or_create_by!(slug: "trading-foundations") do |course|
      course.position = 1
      course.status = "published"
      course.category = "introduction"
      course.title_en = "Trading Foundations"
      course.title_es = "Fundamentos de Trading"
    end

    Course.find_or_create_by!(slug: "beginner-momentum") do |course|
      course.position = 2
      course.status = "published"
      course.category = "momentum"
      course.title_en = "Beginner Momentum"
      course.title_es = "Momentum Inicial"
    end

    Course.find_or_create_by!(slug: "intermediate-systems") do |course|
      course.position = 3
      course.status = "published"
      course.category = "systems"
      course.title_en = "Intermediate Systems"
      course.title_es = "Sistemas Intermedios"
    end

    Course.find_or_create_by!(slug: "orderflow-lab") do |course|
      course.position = 4
      course.status = "published"
      course.category = "intermediate"
      course.title_en = "Orderflow Lab"
      course.title_es = "Laboratorio de orderflow"
    end

    MarketplaceAsset.find_or_create_by!(slug: "quick_start_guide") do |asset|
      asset.sort_order = 1
      asset.status = "active"
      asset.title_en = "Quick Start Guide"
      asset.title_es = "Guia de inicio rapido"
    end

    MarketplaceAsset.find_or_create_by!(slug: "session_templates") do |asset|
      asset.sort_order = 2
      asset.status = "active"
      asset.title_en = "Session Templates"
      asset.title_es = "Plantillas de sesion"
    end

    MarketplaceAsset.find_or_create_by!(slug: "risk_checklist") do |asset|
      asset.sort_order = 3
      asset.status = "active"
      asset.title_en = "Risk Checklist"
      asset.title_es = "Checklist de riesgo"
    end
  end
end
