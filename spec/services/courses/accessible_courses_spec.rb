require "rails_helper"

RSpec.describe Courses::AccessibleCourses do
  let(:user) { create(:user) }
  let!(:free_course) { create(:course, slug: "free-course") }
  let!(:paid_course) { create(:course, slug: "paid-course") }
  let!(:marketplace_course) { create(:course, slug: "marketplace-course") }
  let!(:plan) { create(:billing_plan, tier: "basic") }
  let!(:marketplace_plan) { create(:billing_plan, :one_time) }

  before do
    create(:course_plan_entitlement, course: paid_course, billing_plan: plan)
    create(:course_plan_entitlement, course: marketplace_course, billing_plan: marketplace_plan)
  end

  it "marks free courses as accessible" do
    entries = described_class.new(user: user, tier: nil).call
    entry = entries.find { |e| e.course == free_course }

    expect(entry.accessible).to be(true)
    expect(entry.allowed_tiers).to eq([])
  end

  it "locks paid courses without a tier" do
    entries = described_class.new(user: user, tier: nil).call
    entry = entries.find { |e| e.course == paid_course }

    expect(entry.accessible).to be(false)
    expect(entry.allowed_tiers).to eq(["basic"])
  end

  it "unlocks paid courses for matching tiers" do
    entries = described_class.new(user: user, tier: "basic").call
    entry = entries.find { |e| e.course == paid_course }

    expect(entry.accessible).to be(true)
  end

  it "unlocks paid courses with one-time enrollment access" do
    create(:course_enrollment, :one_time, user: user, course: paid_course)

    entries = described_class.new(user: user, tier: nil).call
    entry = entries.find { |e| e.course == paid_course }

    expect(entry.accessible).to be(true)
  end

  it "locks marketplace-only courses without one-time access" do
    entries = described_class.new(user: user, tier: "basic").call
    entry = entries.find { |e| e.course == marketplace_course }

    expect(entry.accessible).to be(false)
    expect(entry.allowed_tiers).to eq([])
  end

  it "unlocks marketplace-only courses with one-time enrollment access" do
    create(:course_enrollment, :one_time, user: user, course: marketplace_course)

    entries = described_class.new(user: user, tier: "basic").call
    entry = entries.find { |e| e.course == marketplace_course }

    expect(entry.accessible).to be(true)
  end
end
