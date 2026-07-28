require "rails_helper"

RSpec.describe Billing::SubscriptionPlanResolver do
  SubscriptionRecord = Struct.new(:processor_plan, :object, keyword_init: true)

  let!(:catalog) { create_subscription_catalog }

  it "resolves multi-underscore canonical keys without truncating the tier" do
    subscription = SubscriptionRecord.new(processor_plan: catalog[:chu_monthly].stripe_price_id)
    resolver = described_class.new(subscription: subscription)

    expect(resolver.plan).to eq(catalog[:chu_monthly])
    expect(resolver.tier).to eq(Billing::ChuSniperPricing::TIER)
    expect(resolver.interval_key).to eq("monthly")
  end

  it "uses a persisted price id before a conflicting legacy environment key" do
    original = ENV["STRIPE_PRICE_PANDORA_PRO_ANNUAL"]
    ENV["STRIPE_PRICE_PANDORA_PRO_ANNUAL"] = catalog[:chu_annual].stripe_price_id
    subscription = SubscriptionRecord.new(processor_plan: catalog[:chu_annual].stripe_price_id)

    resolver = described_class.new(subscription: subscription)

    expect(resolver.plan).to eq(catalog[:chu_annual])
    expect(resolver.tier).to eq(Billing::ChuSniperPricing::TIER)
  ensure
    ENV["STRIPE_PRICE_PANDORA_PRO_ANNUAL"] = original
  end

  it "parses an unknown legacy key by its interval suffix" do
    original = ENV["STRIPE_PRICE_LEGACY_MULTI_WORD_MONTHLY"]
    ENV["STRIPE_PRICE_LEGACY_MULTI_WORD_MONTHLY"] = "price_legacy_multi_word"
    subscription = SubscriptionRecord.new(processor_plan: "price_legacy_multi_word")

    resolver = described_class.new(subscription: subscription)

    expect(resolver.plan).to be_nil
    expect(resolver.tier).to eq("legacy_multi_word")
    expect(resolver.interval_key).to eq("monthly")
  ensure
    ENV["STRIPE_PRICE_LEGACY_MULTI_WORD_MONTHLY"] = original
  end
end
