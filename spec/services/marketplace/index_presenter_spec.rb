require "rails_helper"

RSpec.describe Marketplace::IndexPresenter do
  let(:user) { create(:user) }

  def build_presenter(params = {})
    described_class.new(user: user, params: params, locale: :en).call
  end

  it "reports empty state when no data is available" do
    presenter = build_presenter

    expect(presenter.empty_state?).to be(true)
    expect(presenter.course_cards).to be_empty
    expect(presenter.digital_goods_cards).to be_empty
    expect(presenter.show_categories?).to be(false)
    expect(presenter.show_trending?).to be(false)
  end

  it "builds cards from marketplace products" do
    course = create(:course, title_en: "Market Course")
    course_plan = create(:billing_plan, :one_time, key: "marketplace_course_bundle")
    course_product = create(:marketplace_product, billing_plan: course_plan, title_en: "Course Bundle")
    create(:course_plan_entitlement, course: course, billing_plan: course_plan)

    expert_advisor = create(:expert_advisor, name: "Alpha EA")
    ea_plan = create(:billing_plan, :one_time, key: "marketplace_ea_bundle")
    ea_product = create(:marketplace_product, billing_plan: ea_plan, title_en: "EA Pack")
    create(:billing_plan_entitlement, expert_advisor: expert_advisor, billing_plan: ea_plan)

    presenter = build_presenter

    expect(presenter.course_cards.map(&:title)).to include(course_product.title_en)
    expect(presenter.digital_goods_cards.map(&:title)).to include(ea_product.title_en)
  end

  it "excludes purchased marketplace products" do
    course = create(:course, title_en: "Exclusive Course")
    plan = create(:billing_plan, :one_time, key: "marketplace_exclusive")
    product = create(:marketplace_product, billing_plan: plan, title_en: "Exclusive Bundle")
    create(:course_plan_entitlement, course: course, billing_plan: plan)
    create(:marketplace_purchase, user: user, billing_plan: plan, purchased_at: 1.day.ago)

    presenter = build_presenter

    expect(presenter.course_cards.map(&:title)).not_to include(product.title_en)
  end

  it "orders course cards by purchase count" do
    course_one = create(:course, title_en: "Course One")
    course_two = create(:course, title_en: "Course Two")

    plan_one = create(:billing_plan, :one_time, key: "marketplace_course_one")
    plan_two = create(:billing_plan, :one_time, key: "marketplace_course_two")

    product_one = create(:marketplace_product, billing_plan: plan_one, title_en: "Bundle One")
    product_two = create(:marketplace_product, billing_plan: plan_two, title_en: "Bundle Two")

    create(:course_plan_entitlement, course: course_one, billing_plan: plan_one)
    create(:course_plan_entitlement, course: course_two, billing_plan: plan_two)

    create(:marketplace_purchase, billing_plan: plan_two, purchased_at: 2.days.ago)
    create(:marketplace_purchase, billing_plan: plan_two, purchased_at: 1.day.ago)
    create(:marketplace_purchase, billing_plan: plan_one, purchased_at: 1.day.ago)

    presenter = build_presenter

    expect(presenter.course_cards.map(&:title).first(2)).to eq([product_two.title_en, product_one.title_en])
  end

  it "orders digital goods cards by purchase count" do
    ea_one = create(:expert_advisor, name: "EA One")
    ea_two = create(:expert_advisor, name: "EA Two")

    plan_one = create(:billing_plan, :one_time, key: "marketplace_ea_one")
    plan_two = create(:billing_plan, :one_time, key: "marketplace_ea_two")

    product_one = create(:marketplace_product, billing_plan: plan_one, title_en: "EA Bundle One")
    product_two = create(:marketplace_product, billing_plan: plan_two, title_en: "EA Bundle Two")

    create(:billing_plan_entitlement, expert_advisor: ea_one, billing_plan: plan_one)
    create(:billing_plan_entitlement, expert_advisor: ea_two, billing_plan: plan_two)

    create(:marketplace_purchase, billing_plan: plan_one, purchased_at: 1.day.ago)
    create(:marketplace_purchase, billing_plan: plan_two, purchased_at: 1.day.ago)
    create(:marketplace_purchase, billing_plan: plan_two, purchased_at: 2.days.ago)

    presenter = build_presenter

    expect(presenter.digital_goods_cards.map(&:title).first(2)).to eq([product_two.title_en, product_one.title_en])
  end

  it "filters by tags across marketplace products" do
    course = create(:course, title_en: "Manual Course")
    course.tag_list = "manual"
    course.save!

    plan = create(:billing_plan, :one_time, key: "marketplace_manual")
    product = create(:marketplace_product, billing_plan: plan, title_en: "Manual Bundle")
    create(:course_plan_entitlement, course: course, billing_plan: plan)

    presenter = build_presenter(tags: ["manual"])

    expect(presenter.course_cards.map(&:title)).to include(product.title_en)
    expect(presenter.digital_goods_cards).to be_empty
  end

  it "builds trending cards from purchases with usage fallback" do
    expert_advisor = create(:expert_advisor, name: "Trend EA")
    ea_plan = create(:billing_plan, :one_time, key: "marketplace_ea_trend")
    ea_product = create(:marketplace_product, billing_plan: ea_plan, title_en: "EA Trend Pack")
    create(:billing_plan_entitlement, expert_advisor: expert_advisor, billing_plan: ea_plan)
    create(:marketplace_purchase, billing_plan: ea_plan, purchased_at: 3.days.ago)

    course = create(:course, title_en: "Trend Course")
    course_plan = create(:billing_plan, :one_time, key: "marketplace_course_trend")
    course_product = create(:marketplace_product, billing_plan: course_plan, title_en: "Course Trend Pack")
    create(:course_plan_entitlement, course: course, billing_plan: course_plan)
    create(:course_enrollment, course: course, user: create(:user), created_at: 2.days.ago)

    presenter = build_presenter

    expect(presenter.trending_cards.map(&:title)).to include(ea_product.title_en, course_product.title_en)
    expect(presenter.trending_cards.first.title).to eq(ea_product.title_en)
  end
end
