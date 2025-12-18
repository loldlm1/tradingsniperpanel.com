require "rails_helper"

RSpec.describe Billing::ConfiguredPrices do
  describe ".resolve_price_id" do
    it "returns price id when given a price id" do
      expect(described_class.resolve_price_id("price_123")).to eq("price_123")
    end

    it "fetches default price when given a product id" do
      product = instance_double(Stripe::Product, default_price: "price_default")
      allow(Stripe::Product).to receive(:retrieve).with("prod_123").and_return(product)

      expect(described_class.resolve_price_id("prod_123")).to eq("price_default")
    end

    it "returns nil on failures" do
      allow(Stripe::Product).to receive(:retrieve).and_raise(StandardError.new("boom"))

      expect(described_class.resolve_price_id("prod_123")).to be_nil
    end
  end

  describe Billing::PriceKeyResolver do
    it "matches price key when env stores product id" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("STRIPE_PRICE_BASIC_MONTHLY").and_return("prod_123")
      allow(Stripe::Product).to receive(:retrieve).with("prod_123").and_return(instance_double(Stripe::Product, default_price: "price_abc"))

      expect(Billing::PriceKeyResolver.key_for_price_id("price_abc")).to eq("basic_monthly")
    end
  end
end
