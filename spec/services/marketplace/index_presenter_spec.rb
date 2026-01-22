require "rails_helper"

RSpec.describe Marketplace::IndexPresenter do
  let(:user) { create(:user) }

  def build_presenter(params = {})
    presenter = described_class.new(user: user, params: params, locale: :en)
    yield presenter if block_given?
    presenter.call
  end

  it "reports empty state when no data is available" do
    presenter = build_presenter

    expect(presenter.empty_state?).to be(true)
    expect(presenter.course_cards).to be_empty
    expect(presenter.digital_goods_cards).to be_empty
    expect(presenter.show_categories?).to be(false)
    expect(presenter.show_trending?).to be(false)
  end

  it "builds course and digital goods cards for the default tab" do
    course = create(:course, title_en: "Alpha Course")
    expert_advisor = create(:expert_advisor, name: "Alpha EA")

    presenter = build_presenter

    expect(presenter.course_cards.map(&:title)).to include(course.title_en)
    expect(presenter.digital_goods_cards.map(&:title)).to include(expert_advisor.name)
  end

  it "respects the courses tab filter" do
    course = create(:course, title_en: "Course Tab")
    create(:expert_advisor, name: "EA Tab")

    presenter = build_presenter(tab: "courses")

    expect(presenter.show_courses?).to be(true)
    expect(presenter.show_digital_goods?).to be(false)
    expect(presenter.course_cards.map(&:title)).to include(course.title_en)
    expect(presenter.digital_goods_cards).to be_empty
    expect(presenter.show_categories?).to be(false)
  end

  it "filters by search terms across expert advisor types" do
    create(:course, title_en: "Risk Course", category: "risk")
    expert_advisor = create(:expert_advisor, name: "Tool EA", ea_type: :ea_tool)

    presenter = build_presenter(q: "ea_tool")

    expect(presenter.digital_goods_cards.map(&:title)).to include(expert_advisor.name)
    expect(presenter.course_cards).to be_empty
  end

  it "filters by tags for courses and expert advisors" do
    course = create(:course, title_en: "Manual Course")
    course.tag_list = "manual"
    course.save!

    expert_advisor = create(:expert_advisor, name: "Auto EA")
    expert_advisor.tag_list = "automation"
    expert_advisor.save!

    presenter = build_presenter(tags: ["manual"])

    expect(presenter.course_cards.map(&:title)).to include(course.title_en)
    expect(presenter.digital_goods_cards).to be_empty
  end

  it "orders course cards by metric priority" do
    best_seller = create(:course, title_en: "Best Seller", published_at: 10.days.ago)
    best_completion = create(:course, title_en: "Best Completion", published_at: 9.days.ago)
    recent = create(:course, title_en: "Most Recent", published_at: 1.day.ago)
    recommended = create(:course, title_en: "Recommended", published_at: 8.days.ago)

    3.times do
      create(:course_enrollment, course: best_seller, user: create(:user), created_at: 2.days.ago, progress_percent: 10)
    end
    create(:course_enrollment, course: best_completion, user: create(:user), created_at: 2.days.ago, progress_percent: 95)
    create(:course_enrollment, course: best_completion, user: create(:user), created_at: 2.days.ago, progress_percent: 90)
    create(:course_enrollment, course: recommended, user: user, created_at: 1.day.ago, progress_percent: 60)

    presenter = build_presenter

    expect(presenter.course_cards.map(&:title)).to eq(
      [best_seller.title_en, best_completion.title_en, recent.title_en, recommended.title_en]
    )
  end

  it "orders digital goods cards by metric priority" do
    usage_ea = create(:expert_advisor, name: "Usage EA", created_at: 5.days.ago)
    pnl_ea = create(:expert_advisor, name: "PnL EA", created_at: 4.days.ago)
    recent_ea = create(:expert_advisor, name: "Recent EA", created_at: 1.hour.ago)
    retention_ea = create(:expert_advisor, name: "Retention EA", created_at: 3.days.ago)

    3.times { create(:license, expert_advisor: usage_ea, status: "active") }
    pnl_license = create(:license, expert_advisor: pnl_ea, status: "active")
    retention_license_one = create(:license, expert_advisor: retention_ea, status: "active")
    retention_license_two = create(:license, expert_advisor: retention_ea, status: "active")

    pnl_account = create(:broker_account, license: pnl_license, account_number: 100_001)
    create(:broker_account_daily_result, broker_account: pnl_account, result_timestamp: 2.days.ago.to_i, result_value: 500)
    [retention_license_one, retention_license_two].each_with_index do |license, index|
      account = create(:broker_account, license: license, account_number: 100_002 + index)
      create(:broker_account_daily_result, broker_account: account, result_timestamp: 2.days.ago.to_i, result_value: 10)
    end

    presenter = build_presenter

    expect(presenter.digital_goods_cards.map(&:title)).to eq(
      [usage_ea.name, pnl_ea.name, recent_ea.name, retention_ea.name]
    )
  end

  it "orders trending cards by section priority" do
    expert_advisor = create(:expert_advisor, name: "Trend EA")
    license = create(:license, expert_advisor: expert_advisor, status: "active")

    course = create(:course, title_en: "Trend Course", published_at: 2.days.ago)
    create(:course_enrollment, course: course, user: create(:user), created_at: 1.day.ago)

    addon = create(:addon, addonable: expert_advisor)
    product = create(:marketplace_product, billing_plan: addon.billing_plan, title_en: "Trend Addon")
    create(:marketplace_purchase, billing_plan: addon.billing_plan, purchased_at: 1.day.ago)

    create(:broker_account_daily_result,
           broker_account: create(:broker_account, license: license),
           result_timestamp: 2.days.ago.to_i,
           result_value: 10)

    presenter = build_presenter do |instance|
      allow(instance).to receive(:most_chosen_plan).and_return(nil)
    end

    expect(presenter.trending_cards.map(&:title)).to eq(
      [expert_advisor.name, course.title_en, product.title_en]
    )
  end
end
