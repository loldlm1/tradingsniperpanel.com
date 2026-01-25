require "rails_helper"

RSpec.describe "Dashboard analytics", type: :request do
  let(:user) { create(:user) }
  let(:expert_advisor) { create(:expert_advisor, name: "Grid Guard") }
  let!(:license) { create(:license, user: user, expert_advisor: expert_advisor, status: "active") }
  let!(:broker_accounts) do
    Array.new(2) do |index|
      create(:broker_account,
             license: license,
             company: "PagedFX",
             account_number: 2000 + index,
             account_type: index.even? ? :real : :demo)
    end
  end

  before do
    sign_in user, scope: :user
  end

  def seed_analytics_data(now: Time.current)
    create(
      :broker_account_daily_result,
      broker_account: broker_accounts.first,
      result_timestamp: now.to_i,
      result_value: 12.5
    )
    create(
      :broker_account_daily_result,
      broker_account: broker_accounts.second,
      result_timestamp: now.to_i,
      result_value: -4.0
    )

    course = create(:course, title_en: "Risk Basics", title_es: "Riesgo Basico", category: "risk")
    course_module = create(:course_module, course: course)
    lesson = create(:course_lesson, course_module: course_module, duration_seconds: 600)

    create(:course_enrollment, user: user, course: course, progress_percent: 55, updated_at: now - 2.days)
    create(
      :course_lesson_progress,
      user: user,
      course_lesson: lesson,
      progress_seconds: 300,
      last_watched_at: now - 1.day
    )

    second_ea = create(:expert_advisor, name: "Trend Watch", ea_type: :indicator)
    create(
      :license,
      user: user,
      expert_advisor: second_ea,
      status: "trial",
      trial_ends_at: now + 5.days,
      expires_at: now + 5.days
    )
  end

  def expect_headings(locale)
    keys = %w[
      dashboard.analytics.cards.daily_performance.title
      dashboard.analytics.cards.active_now.title
      dashboard.analytics.cards.ea_results.title
      dashboard.analytics.cards.course_progress.title
      dashboard.analytics.cards.top_eas.title
      dashboard.analytics.cards.latest_lessons.title
      dashboard.analytics.cards.expiring_licenses.title
      dashboard.analytics.cards.course_status.title
      dashboard.analytics.cards.study_time.title
      dashboard.analytics.cards.ea_types.title
    ]

    keys.each do |key|
      expect(response.body).to include(I18n.t(key, locale: locale))
    end
  end

  it "renders analytics layout with comment markers, IDs, and EN headings" do
    seed_analytics_data
    get dashboard_analytics_path

    expect(response).to be_successful

    comment_markers = [
      "<!-- Page header -->",
      "<!-- Left: Title -->",
      "<!-- Right: Actions -->",
      "<!-- Datepicker built with flatpickr -->",
      "<!-- Cards -->",
      "<!-- Line chart (Analytics) -->",
      "<!--  Line chart (Active Users Right Now) -->",
      "<!-- Stacked bar chart (Acquisition Channels) -->",
      "<!-- Horizontal bar chart (Audience Overview) -->",
      "<!-- Report card (Top Channels) -->",
      "<!-- Report card (Top Pages) -->",
      "<!-- Report card (Top Countries) -->",
      "<!-- Doughnut chart (Sessions By Device) -->",
      "<!-- Doughnut chart (Visit By Age Category) -->",
      "<!-- Polar chart (Sessions By Gender) -->"
    ]

    comment_markers.each do |marker|
      expect(response.body).to include(marker)
    end

    chart_ids = %w[
      analytics-card-01
      analytics-card-02
      analytics-card-03
      analytics-card-04
      analytics-card-08
      analytics-card-09
      analytics-card-10
    ]
    legend_ids = %w[
      analytics-card-03-legend
      analytics-card-04-legend
      analytics-card-08-legend
      analytics-card-09-legend
      analytics-card-10-legend
    ]

    (chart_ids + legend_ids).each do |element_id|
      expect(response.body).to include(%(id="#{element_id}"))
    end

    expect_headings(:en)
  end

  it "renders analytics headings in ES locale" do
    seed_analytics_data
    get dashboard_analytics_path(locale: :es)

    expect(response).to be_successful
    expect_headings(:es)
  end
end
