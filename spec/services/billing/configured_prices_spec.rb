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

    it "accepts a retired historical price id" do
      history = create(:billing_plan_price, active: false, retired_at: Time.current)

      expect(described_class.resolve_price_id(history.stripe_price_id)).to eq(history.stripe_price_id)
      expect(described_class.all_price_ids).to include(history.stripe_price_id)
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

    it "matches a retired historical price id to its plan key" do
      plan = create(:billing_plan, key: "basic_monthly", tier: "basic")
      history = create(:billing_plan_price, billing_plan: plan, active: false, retired_at: Time.current)

      expect(Billing::PriceKeyResolver.key_for_price_id(history.stripe_price_id)).to eq("basic_monthly")
    end
  end
end
