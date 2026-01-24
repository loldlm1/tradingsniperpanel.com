require "rails_helper"

RSpec.describe Courses::IndexPresenter do
  include Rails.application.routes.url_helpers

  describe "#tag_filters" do
    it "uses progressed courses when available" do
      course_a = create(:course, category: "beginner")
      course_a.tag_list = %w[alpha]
      course_a.save!

      course_b = create(:course, category: "beginner")
      course_b.tag_list = %w[beta]
      course_b.save!

      course_c = create(:course, category: "beginner")
      course_c.tag_list = %w[alpha]
      course_c.save!

      entry_a = Courses::AccessibleCourses::Entry.new(
        course: course_a,
        accessible: true,
        allowed_tiers: [],
        cta_plan: nil,
        progress_percent: 10
      )
      entry_b = Courses::AccessibleCourses::Entry.new(
        course: course_b,
        accessible: true,
        allowed_tiers: [],
        cta_plan: nil,
        progress_percent: 0
      )
      entry_c = Courses::AccessibleCourses::Entry.new(
        course: course_c,
        accessible: true,
        allowed_tiers: [],
        cta_plan: nil,
        progress_percent: 35
      )

      presenter = described_class.new(entries: [entry_a, entry_b, entry_c], locale: :en)
      filters = presenter.send(:tag_filters)

      expect(filters.map(&:value)).to include("alpha")
      expect(filters.map(&:value)).not_to include("beta")
      expect(filters.find { |filter| filter.value == "alpha" }&.count).to eq(2)
    end

    it "falls back to total course tags when no progress exists" do
      course_a = create(:course, category: "beginner")
      course_a.tag_list = %w[alpha]
      course_a.save!

      course_b = create(:course, category: "beginner")
      course_b.tag_list = %w[beta]
      course_b.save!

      entry_a = Courses::AccessibleCourses::Entry.new(
        course: course_a,
        accessible: true,
        allowed_tiers: [],
        cta_plan: nil,
        progress_percent: 0
      )
      entry_b = Courses::AccessibleCourses::Entry.new(
        course: course_b,
        accessible: true,
        allowed_tiers: [],
        cta_plan: nil,
        progress_percent: 0
      )

      presenter = described_class.new(entries: [entry_a, entry_b], locale: :en)
      values = presenter.send(:tag_filters).map(&:value)

      expect(values).to include("alpha", "beta")
    end
  end

  describe "#cards" do
    it "prefers marketplace unlock urls when available" do
      course = create(:course, category: "beginner")
      subscription_plan = create(:billing_plan, tier: "pro")
      product = create(:marketplace_product)
      create(:course_plan_entitlement, course: course, billing_plan: product.billing_plan)

      entry = Courses::AccessibleCourses::Entry.new(
        course: course,
        accessible: false,
        allowed_tiers: [],
        cta_plan: subscription_plan,
        progress_percent: 0
      )

      presenter = described_class.new(entries: [entry], locale: :en, marketplace_available: true)
      card = presenter.cards.first

      expect(card.unlock_url).to eq(dashboard_marketplace_product_path(product, locale: :en))
    end

    it "falls back to subscription plans when no marketplace product exists" do
      course = create(:course, category: "beginner")
      subscription_plan = create(:billing_plan, tier: "pro")

      entry = Courses::AccessibleCourses::Entry.new(
        course: course,
        accessible: false,
        allowed_tiers: [],
        cta_plan: subscription_plan,
        progress_percent: 0
      )

      presenter = described_class.new(entries: [entry], locale: :en, marketplace_available: false)
      card = presenter.cards.first

      expect(card.unlock_url).to eq(dashboard_plans_path(price_key: subscription_plan.key, locale: :en))
    end
  end
end
