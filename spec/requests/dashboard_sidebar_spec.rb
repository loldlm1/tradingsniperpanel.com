require "rails_helper"

RSpec.describe "Dashboard sidebar", type: :request do
  let(:user) { create(:user) }

  before do
    sign_in user, scope: :user
  end

  def parsed_body
    Nokogiri::HTML(response.body)
  end

  def sidebar_group_items(doc, label)
    sidebar = doc.at_css("#sidebar")
    link = sidebar.css("a").find { |anchor| anchor.text.strip == label }
    group = link&.ancestors("li")&.first
    return [] unless group

    group.css("ul > li a").map { |anchor| anchor.text.strip.gsub(/\s+/, " ") }
  end

  def child_labels(items)
    items.drop(1).map { |text| text.sub(/^\d+\s+/, "") }
  end

  it "orders sidebar expert advisors by recent sync then fallback rank" do
    synced_new = create(:expert_advisor, name: "Synced New", tier_rank: 5)
    synced_old = create(:expert_advisor, name: "Synced Old", tier_rank: 1)
    create(:license, user: user, expert_advisor: synced_new, last_synced_at: 1.day.ago)
    create(:license, user: user, expert_advisor: synced_old, last_synced_at: 3.days.ago)

    fallback_a = create(:expert_advisor, name: "Fallback A", tier_rank: 2)
    fallback_b = create(:expert_advisor, name: "Fallback B", tier_rank: 1)
    fallback_c = create(:expert_advisor, name: "Fallback C", tier_rank: 3)
    create(:expert_advisor, name: "Fallback D", tier_rank: 4)

    get dashboard_path(locale: :en)

    items = sidebar_group_items(parsed_body, "Expert Advisors")
    expect(items.first).to eq("All Expert Advisors")
    expect(child_labels(items)).to eq([
      synced_new.name,
      synced_old.name,
      fallback_b.name,
      fallback_a.name,
      fallback_c.name
    ])
  end

  it "orders sidebar courses by recent lesson watch then published date" do
    recent_new = create(:course, title_en: "Recent New", published_at: 10.days.ago)
    recent_old = create(:course, title_en: "Recent Old", published_at: 9.days.ago)

    module_new = create(:course_module, course: recent_new)
    module_old = create(:course_module, course: recent_old)
    lesson_new = create(:course_lesson, course_module: module_new)
    lesson_old = create(:course_lesson, course_module: module_old)

    create(:course_lesson_progress, user: user, course_lesson: lesson_new, last_watched_at: 1.day.ago)
    create(:course_lesson_progress, user: user, course_lesson: lesson_old, last_watched_at: 4.days.ago)

    fallback_newest = create(:course, title_en: "Fallback Newest", published_at: 3.days.ago)
    fallback_mid = create(:course, title_en: "Fallback Mid", published_at: 6.days.ago)
    fallback_old = create(:course, title_en: "Fallback Old", published_at: 8.days.ago)
    create(:course, title_en: "Fallback Extra", published_at: 9.days.ago)

    get dashboard_path(locale: :en)

    items = sidebar_group_items(parsed_body, "Courses")
    expect(items.first).to eq("All Courses")
    expect(child_labels(items)).to eq([
      recent_new.title_en,
      recent_old.title_en,
      fallback_newest.title_en,
      fallback_mid.title_en,
      fallback_old.title_en
    ])
  end
end
