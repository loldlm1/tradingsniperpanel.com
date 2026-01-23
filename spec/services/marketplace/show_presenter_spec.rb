require "rails_helper"

RSpec.describe Marketplace::ShowPresenter do
  let(:user) { create(:user) }
  let(:expert_advisor) { create(:expert_advisor, name: "Alpha EA") }

  it "selects the first base product for add-on entries and preselects the add-on" do
    base_plan_one = create(:billing_plan, :one_time)
    base_product_one = create(:marketplace_product, billing_plan: base_plan_one, sort_order: 0, title_en: "Base One")
    create(:billing_plan_entitlement, billing_plan: base_plan_one, expert_advisor: expert_advisor)

    base_plan_two = create(:billing_plan, :one_time)
    base_product_two = create(:marketplace_product, billing_plan: base_plan_two, sort_order: 2, title_en: "Base Two")
    create(:billing_plan_entitlement, billing_plan: base_plan_two, expert_advisor: expert_advisor)

    addon_plan = create(:billing_plan, :one_time, key: "addon_plan")
    create(:addon, addonable: expert_advisor, billing_plan: addon_plan)
    addon_product = create(:marketplace_product, billing_plan: addon_plan, title_en: "Addon Pack")

    entry = Marketplace::Catalog.new(user: user).entry_for!(slug: addon_product.slug)

    presenter = described_class.new(user: user, entry: entry, locale: :en).call

    expect(presenter.base_product).to eq(base_product_one)
    expect(presenter.addon_rows.map(&:plan_key)).to include(addon_plan.key)
    expect(presenter.selected_addon_keys).to include(addon_plan.key)
    expect(presenter.base_product).not_to eq(base_product_two)
  end

  it "hides already owned add-ons from the list" do
    base_plan = create(:billing_plan, :one_time)
    base_product = create(:marketplace_product, billing_plan: base_plan, title_en: "Base")
    create(:billing_plan_entitlement, billing_plan: base_plan, expert_advisor: expert_advisor)

    addon_plan = create(:billing_plan, :one_time)
    create(:addon, addonable: expert_advisor, billing_plan: addon_plan)
    create(:marketplace_product, billing_plan: addon_plan, title_en: "Owned Addon")
    create(:marketplace_purchase, user: user, billing_plan: addon_plan)

    entry = Marketplace::Catalog.new(user: user).entry_for!(slug: base_product.slug)
    presenter = described_class.new(user: user, entry: entry, locale: :en).call

    expect(presenter.addon_rows.map(&:plan_key)).not_to include(addon_plan.key)
  end
end
