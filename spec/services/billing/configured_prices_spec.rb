require "rails_helper"

RSpec.describe Billing::ConfiguredPrices do
  describe ".price_id_for" do
    it "returns only exact current Pandora prices" do
      monthly = create(
        :billing_plan,
        tier: Billing::PandoraPricing::TIER,
        key: Billing::PandoraPricing::MONTHLY_KEY,
        amount_cents: Billing::PandoraPricing::MONTHLY_CENTS
      )
      create(:billing_plan, tier: "basic", key: "basic_monthly", stripe_price_id: "price_old")

      expect(described_class.price_id_for(Billing::PandoraPricing::MONTHLY_KEY)).to eq(monthly.stripe_price_id)
      expect(described_class.price_id_for("basic_monthly")).to be_nil
    end

    it "does not fall back to legacy environment prices" do
      original = ENV["STRIPE_PRICE_BASIC_MONTHLY"]
      ENV["STRIPE_PRICE_BASIC_MONTHLY"] = "price_legacy"

      expect(described_class.price_id_for("basic_monthly")).to be_nil
    ensure
      ENV["STRIPE_PRICE_BASIC_MONTHLY"] = original
    end
  end

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
