require "rails_helper"

RSpec.describe Billing::SubscriptionCatalog do
  it "defines ordered products, shared VIP eligibility, and the entitlement matrix" do
    expect(described_class.tiers).to eq(%w[chu_sniper_trailing pandora_pro])
    expect(described_class.access_rank_for("chu_sniper_trailing")).to eq(1)
    expect(described_class.access_rank_for("pandora_pro")).to eq(2)
    expect(described_class.seat_cap_for("chu_sniper_trailing")).to eq(5)
    expect(described_class.seat_cap_for("pandora_pro")).to eq(5)
    expect(described_class.vip_eligible?("chu_sniper_trailing")).to be(true)
    expect(described_class.vip_eligible?("pandora_pro")).to be(true)
    expect(described_class.ea_ids_for_tier("chu_sniper_trailing")).to eq([ "chu_sniper_trailing" ])
    expect(described_class.ea_ids_for_tier("pandora_pro")).to eq([ "pandora_box", "chu_sniper_trailing" ])
  end

  it "parses known multi-underscore keys without losing the tier" do
    parsed = described_class.parse_plan_key("chu_sniper_trailing_annual")

    expect(parsed).to include(
      tier: "chu_sniper_trailing",
      interval_key: "annual",
      canonical: true
    )
    expect(parsed.fetch(:product).catalog_key).to eq("chu_sniper_trailing")
  end

  it "keeps unknown keys as a non-canonical safe fallback" do
    expect(described_class.parse_plan_key("legacy_multi_word_monthly")).to include(
      tier: "legacy_multi_word",
      interval_key: "monthly",
      canonical: false,
      product: nil
    )
  end

  it "marks only complete product pairs as purchasable" do
    create_canonical_plan(Billing::ChuSniperPricing, "chu_sniper_trailing")
    create_canonical_plan(Billing::PandoraPricing, "pandora_box")
    legacy = create(:billing_plan, tier: "legacy_multi_word", key: "legacy_multi_word_monthly")

    complete = described_class.complete_products(BillingPlan.subscription.active.to_a)

    expect(complete.map(&:tier)).to contain_exactly(Billing::ChuSniperPricing::TIER, Billing::PandoraPricing::TIER)
    expect(legacy).to be_persisted
  end

  def create_canonical_plan(pricing, catalog_product)
    pricing::PLAN_DEFINITIONS.each do |key, definition|
      create(
        :billing_plan,
        key: key,
        name: "#{catalog_product} #{key}",
        tier: pricing::TIER,
        interval: definition.fetch(:interval),
        interval_count: definition.fetch(:interval_count),
        amount_cents: definition.fetch(:amount_cents),
        metadata: { "catalog_product" => catalog_product }
      )
    end
  end
end
