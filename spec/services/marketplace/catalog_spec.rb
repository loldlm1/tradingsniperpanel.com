require "rails_helper"

RSpec.describe Marketplace::Catalog do
  let(:user) { create(:user) }

  it "aggregates tags from included items" do
    plan = create(:billing_plan, :one_time)
    product = create(:marketplace_product, billing_plan: plan, title_en: "Bundle")

    expert_advisor = create(:expert_advisor)
    expert_advisor.tag_list = "automation"
    expert_advisor.save!

    course = create(:course, slug: "tagged-course")
    course.tag_list = "manual"
    course.save!

    asset = create(:marketplace_asset)
    asset.tag_list = "pdf"
    asset.save!

    create(:billing_plan_entitlement, billing_plan: plan, expert_advisor: expert_advisor)
    create(:course_plan_entitlement, billing_plan: plan, course: course)
    create(:asset_plan_entitlement, billing_plan: plan, marketplace_asset: asset)

    entry = described_class.new(user: user).call.detect { |item| item.product == product }

    expect(entry.tags).to match_array(%w[automation manual pdf])
  end

  it "includes tags from addonable items" do
    asset = create(:marketplace_asset)
    asset.tag_list = "rules"
    asset.save!

    addon_plan = create(:billing_plan, :one_time)
    product = create(:marketplace_product, billing_plan: addon_plan, title_en: "Addon")
    create(:addon, addonable: asset, billing_plan: addon_plan)

    entry = described_class.new(user: user).call.detect { |item| item.product == product }

    expect(entry.tags).to eq(["rules"])
  end
end
