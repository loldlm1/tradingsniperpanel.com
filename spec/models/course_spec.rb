require "rails_helper"

RSpec.describe Course, type: :model do
  it "allows any tier when no entitlements exist" do
    course = create(:course)

    expect(course.subscription_tiers).to eq([])
    expect(course.free_access?).to be(true)
    expect(course.allowed_for_tier?(nil)).to be(true)
    expect(course.allowed_for_tier?("basic")).to be(true)
  end

  it "resolves subscription tiers from billing plans" do
    course = create(:course)
    plan = create(:billing_plan, tier: "basic")
    create(:course_plan_entitlement, course: course, billing_plan: plan)

    expect(course.subscription_tiers).to eq(["basic"])
    expect(course.free_access?).to be(false)
    expect(course.allowed_for_tier?("basic")).to be(true)
    expect(course.allowed_for_tier?("pro")).to be(false)
  end

  it "treats one-time entitlements without subscriptions as marketplace-only" do
    course = create(:course)
    plan = create(:billing_plan, :one_time)
    create(:course_plan_entitlement, course: course, billing_plan: plan)

    expect(course.subscription_tiers).to eq([])
    expect(course.marketplace_only?).to be(true)
    expect(course.free_access?).to be(false)
    expect(course.allowed_for_tier?(nil)).to be(false)
    expect(course.allowed_for_tier?("basic")).to be(false)
  end
end
