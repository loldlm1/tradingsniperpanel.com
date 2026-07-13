require "rails_helper"

RSpec.describe "Marketplace seeds" do
  before do
    load Rails.root.join("db", "seeds", "shared.rb") unless defined?(Seeds::MarketplaceProducts)
  end

  it "has no desired marketplace products or add-ons" do
    expect(Seeds::MarketplaceProducts.definitions).to be_empty
    expect(Seeds::Addons.definitions).to be_empty

    expect { Seeds::MarketplaceProducts.seed_products! }.not_to change(MarketplaceProduct, :count)
    expect { Seeds::Addons.seed_addons! }.not_to change(Addon, :count)
  end

  it "drafts every legacy marketplace product when pruning" do
    plan = create(:billing_plan, :one_time)
    product = create(:marketplace_product, billing_plan: plan, status: "active")

    Seeds::MarketplaceProducts.prune_for_profile!

    expect(product.reload).to be_draft
    expect(plan.reload).not_to be_active
  end
end
