require "rails_helper"

RSpec.describe Admin::MarketplaceProductUpsert do
  let(:product) { create(:marketplace_product) }
  let(:product_manager) { instance_double(Marketplace::ProductManager) }

  before do
    allow(Marketplace::ProductManager).to receive(:new).and_return(product_manager)
    allow(product_manager).to receive(:update!).and_return(product)
    allow(product_manager).to receive(:create!).and_return(product)
  end

  it "derives the add-on key from the product slug and syncs entitlements" do
    course = create(:course)

    result = described_class.new(
      product: product,
      product_attributes: { title_en: "Updated" },
      plan_attributes: {},
      entitlement_attributes: { course_ids: [course.id] },
      addon_attributes: { addonable_type: "Course", addonable_id: course.id }
    ).call

    expect(result).to be_ok
    addon = product.billing_plan.reload.addon
    expect(addon).to be_present
    expect(addon.key).to eq(product.slug)
    expect(addon.addonable).to eq(course)
    expect(CoursePlanEntitlement.where(course: course, billing_plan: product.billing_plan)).to exist
  end

  it "rejects asset add-ons without a base marketplace product" do
    asset = create(:marketplace_asset)

    result = described_class.new(
      product: product,
      product_attributes: {},
      plan_attributes: {},
      entitlement_attributes: {},
      addon_attributes: { addonable_type: "MarketplaceAsset", addonable_id: asset.id }
    ).call

    expect(result.ok?).to be(false)
    expect(result.errors).to include(I18n.t("active_admin.marketplace_products.errors.asset_base_missing"))
    expect(product.billing_plan.reload.addon).to be_nil
  end

  it "blocks expert advisor add-ons when bundles are missing" do
    expert_advisor = create(:expert_advisor)
    product = create(:marketplace_product, slug: "addon_bundle", key: "marketplace_addon_bundle")

    result = described_class.new(
      product: product,
      product_attributes: {},
      plan_attributes: {},
      entitlement_attributes: {},
      addon_attributes: { addonable_type: "ExpertAdvisor", addonable_id: expert_advisor.id }
    ).call

    expect(result.ok?).to be(false)
    message = result.errors.join(" ")
    expect(message).to include("base")
    expect(message).to include("addon_bundle")
  end

  it "reports Stripe failures" do
    allow(product_manager).to receive(:update!).and_raise(Stripe::InvalidRequestError.new("boom", nil))

    result = described_class.new(
      product: product,
      product_attributes: {},
      plan_attributes: {},
      entitlement_attributes: {},
      addon_attributes: {}
    ).call

    expect(result.ok?).to be(false)
    expect(result.errors.join(" ")).to include("boom")
  end

  it "requires an amount when creating a new product" do
    result = described_class.new(
      product_attributes: { slug: "new_product", title_en: "New", title_es: "Nuevo", status: "active", sort_order: 0 },
      plan_attributes: {},
      entitlement_attributes: {},
      addon_attributes: {}
    ).call

    expect(result.ok?).to be(false)
    expect(result.errors).to include(I18n.t("active_admin.marketplace_products.errors.amount_missing"))
  end
end
