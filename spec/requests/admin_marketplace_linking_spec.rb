require "rails_helper"

RSpec.describe "Marketplace product linking admin", type: :request do
  it "allows admins to update expert advisors" do
    admin = create(:user, :admin)
    expert_advisor = create(:expert_advisor)
    sign_in admin, scope: :user

    patch admin_expert_advisor_path(expert_advisor), params: {
      expert_advisor: { marketplace_product_ids: [] }
    }

    expect(response).to redirect_to(admin_expert_advisor_path(expert_advisor))
  end

  it "allows admins to update courses" do
    admin = create(:user, :admin)
    course = create(:course)
    sign_in admin, scope: :user

    patch admin_course_path(course), params: {
      course: { marketplace_product_ids: [] }
    }

    expect(response).to redirect_to(admin_course_path(course))
  end

  it "allows admins to update marketplace assets" do
    admin = create(:user, :admin)
    asset = create(:marketplace_asset)
    sign_in admin, scope: :user

    patch admin_marketplace_asset_path(asset), params: {
      marketplace_asset: { marketplace_product_ids: [] }
    }

    expect(response).to redirect_to(admin_marketplace_asset_path(asset))
  end

  it "syncs expert advisor entitlements and keeps subscription access" do
    master_admin = create(:user, :master_admin)
    expert_advisor = create(:expert_advisor)
    subscription_plan = create(:billing_plan)
    create(:billing_plan_entitlement, billing_plan: subscription_plan, expert_advisor: expert_advisor)
    product_a = create(:marketplace_product)
    product_b = create(:marketplace_product)
    create(:billing_plan_entitlement, billing_plan: product_a.billing_plan, expert_advisor: expert_advisor)
    create(:billing_plan_entitlement, billing_plan: product_b.billing_plan, expert_advisor: expert_advisor)
    sign_in master_admin, scope: :user

    patch admin_expert_advisor_path(expert_advisor), params: {
      expert_advisor: { marketplace_product_ids: [product_a.id] }
    }

    plan_ids = BillingPlanEntitlement.where(expert_advisor: expert_advisor).pluck(:billing_plan_id)
    expect(plan_ids).to include(subscription_plan.id, product_a.billing_plan_id)
    expect(plan_ids).not_to include(product_b.billing_plan_id)
  end

  it "syncs course entitlements and keeps subscription access" do
    master_admin = create(:user, :master_admin)
    course = create(:course)
    subscription_plan = create(:billing_plan)
    create(:course_plan_entitlement, billing_plan: subscription_plan, course: course)
    product_a = create(:marketplace_product)
    product_b = create(:marketplace_product)
    create(:course_plan_entitlement, billing_plan: product_a.billing_plan, course: course)
    create(:course_plan_entitlement, billing_plan: product_b.billing_plan, course: course)
    sign_in master_admin, scope: :user

    patch admin_course_path(course), params: {
      course: { marketplace_product_ids: [product_a.id] }
    }

    plan_ids = CoursePlanEntitlement.where(course: course).pluck(:billing_plan_id)
    expect(plan_ids).to include(subscription_plan.id, product_a.billing_plan_id)
    expect(plan_ids).not_to include(product_b.billing_plan_id)
  end

  it "syncs asset entitlements and keeps subscription access" do
    master_admin = create(:user, :master_admin)
    asset = create(:marketplace_asset)
    subscription_plan = create(:billing_plan)
    create(:asset_plan_entitlement, billing_plan: subscription_plan, marketplace_asset: asset)
    product_a = create(:marketplace_product)
    product_b = create(:marketplace_product)
    create(:asset_plan_entitlement, billing_plan: product_a.billing_plan, marketplace_asset: asset)
    create(:asset_plan_entitlement, billing_plan: product_b.billing_plan, marketplace_asset: asset)
    sign_in master_admin, scope: :user

    patch admin_marketplace_asset_path(asset), params: {
      marketplace_asset: { marketplace_product_ids: [product_a.id] }
    }

    plan_ids = AssetPlanEntitlement.where(marketplace_asset: asset).pluck(:billing_plan_id)
    expect(plan_ids).to include(subscription_plan.id, product_a.billing_plan_id)
    expect(plan_ids).not_to include(product_b.billing_plan_id)
  end
end
