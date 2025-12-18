require "rails_helper"

RSpec.describe Billing::PricingCatalog do
  let(:service) { described_class.new }

  around do |example|
    original_env = ENV.to_hash
    begin
      Rails.cache.clear
      ENV["STRIPE_SECRET_KEY"] = "sk_test"
      ENV["STRIPE_PRICE_BASIC_MONTHLY"] = "price_basic_monthly"
      ENV["STRIPE_PRICE_HFT_MONTHLY"] = nil
      ENV["STRIPE_PRICE_PRO_MONTHLY"] = nil
      ENV["STRIPE_PRICE_BASIC_ANNUAL"] = "prod_basic"
      ENV["STRIPE_PRICE_HFT_ANNUAL"] = nil
      ENV["STRIPE_PRICE_PRO_ANNUAL"] = nil
      example.run
    ensure
      ENV.replace(original_env)
    end
  end

  it "falls back to a product default price when ENV contains a product id" do
    allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("development"))

    monthly_price = double(unit_amount: 1900, currency: "usd")
    annual_product = double(default_price: "price_basic_annual_default")
    annual_price = double(unit_amount: 18000, currency: "usd")

    expect(Stripe::Price).to receive(:retrieve).with("price_basic_monthly").and_return(monthly_price)
    expect(Stripe::Price).to receive(:retrieve).with("prod_basic").and_raise(Stripe::InvalidRequestError.new("No such price", {}))
    expect(Stripe::Product).to receive(:retrieve).with("prod_basic").and_return(annual_product)
    expect(Stripe::Price).to receive(:retrieve).with("price_basic_annual_default").and_return(annual_price)

    catalog = service.call

    expect(catalog.dig(:annual, :basic, :display)).to eq("180")
    expect(catalog.dig(:annual, :discount_percent)).to be_a(Integer)
  end
end
