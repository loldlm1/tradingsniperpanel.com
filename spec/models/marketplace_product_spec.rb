require "rails_helper"

RSpec.describe MarketplaceProduct, type: :model do
  it "assigns a marketplace key from the slug" do
    plan = create(:billing_plan, :one_time, key: "marketplace_example_bundle")
    product = described_class.new(
      slug: "example_bundle",
      status: "active",
      sort_order: 0,
      title_en: "Example",
      title_es: "Ejemplo",
      billing_plan: plan
    )

    expect(product).to be_valid
    expect(product.key).to eq("marketplace_example_bundle")
  end

  it "requires a one-time billing plan" do
    plan = create(:billing_plan, kind: "subscription")
    product = build(:marketplace_product, billing_plan: plan)

    expect(product).not_to be_valid
    expect(product.errors[:billing_plan]).to be_present
  end
end
