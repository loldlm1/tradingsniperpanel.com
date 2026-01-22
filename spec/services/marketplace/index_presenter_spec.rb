require "rails_helper"

RSpec.describe Marketplace::IndexPresenter do
  let(:user) { create(:user) }

  def build_presenter(params = {})
    described_class.new(user: user, params: params, locale: :en).call
  end

  it "builds course and digital goods cards for the default tab" do
    course = create(:course, title_en: "Alpha Course")
    expert_advisor = create(:expert_advisor, name: "Alpha EA")

    presenter = build_presenter

    expect(presenter.course_cards.map(&:title)).to include(course.title_en)
    expect(presenter.digital_goods_cards.map(&:title)).to include(expert_advisor.name)
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
end
