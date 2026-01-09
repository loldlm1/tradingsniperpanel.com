require "rails_helper"

RSpec.describe Billing::ConfiguredPrices do
  describe ".resolve_price_id" do
    it "returns price id when given a matching billing plan price" do
      create(:billing_plan, tier: "basic", key: "basic_monthly", interval: "month", interval_count: 1, stripe_price_id: "price_123")

      expect(described_class.resolve_price_id("price_123")).to eq("price_123")
    end

    it "returns billing plan price when given a matching product id" do
      create(:billing_plan, tier: "basic", key: "basic_monthly", interval: "month", interval_count: 1, stripe_product_id: "prod_123", stripe_price_id: "price_default")

      expect(described_class.resolve_price_id("prod_123")).to eq("price_default")
    end
  end

  describe Billing::PriceKeyResolver do
    it "matches price key for a billing plan price id" do
      create(:billing_plan, tier: "basic", key: "basic_monthly", interval: "month", interval_count: 1, stripe_price_id: "price_abc")

      expect(Billing::PriceKeyResolver.key_for_price_id("price_abc")).to eq("basic_monthly")
    end

    it "matches price key for a billing plan product id" do
      create(:billing_plan, tier: "basic", key: "basic_monthly", interval: "month", interval_count: 1, stripe_product_id: "prod_abc")

      expect(Billing::PriceKeyResolver.key_for_product_id("prod_abc")).to eq("basic_monthly")
    end
  end
end
