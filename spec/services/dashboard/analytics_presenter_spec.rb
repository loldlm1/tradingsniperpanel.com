require "rails_helper"

RSpec.describe Dashboard::AnalyticsPresenter do
  def build_presenter(user:, filters: {}, now: Time.current)
    described_class.new(user: user, filters: filters, now: now).call
  end

  context "with broker data" do
    let(:user) { create(:user) }
    let(:expert_advisor) { create(:expert_advisor, name: "EA Alpha", ea_id: "ea-alpha") }
    let!(:license) { create(:license, user: user, expert_advisor: expert_advisor, status: "active") }
    let!(:real_account) { create(:broker_account, license: license, account_type: :real, account_number: 1001) }
    let!(:demo_account) { create(:broker_account, license: license, account_type: :demo, account_number: 1002) }

    it "builds daily performance totals and chart data for the selected range" do
      now = Time.utc(2025, 1, 3, 12, 0, 0)

      create(:broker_account_daily_result, broker_account: real_account, result_timestamp: Time.utc(2025, 1, 1, 12, 0, 0).to_i, result_value: 10.0)
      create(:broker_account_daily_result, broker_account: demo_account, result_timestamp: Time.utc(2025, 1, 2, 12, 0, 0).to_i, result_value: -5.0)
      create(:broker_account_daily_result, broker_account: real_account, result_timestamp: Time.utc(2025, 1, 3, 12, 0, 0).to_i, result_value: 7.0)

      presenter = build_presenter(user: user, filters: { from_date: "2025-01-01", to_date: "2025-01-03" }, now: now)
      daily = presenter.daily_performance

      expect(daily[:chart][:labels]).to eq(["2025-01-01", "2025-01-02", "2025-01-03"])
      expect(daily[:chart][:datasets].first[:data]).to eq([10.0, -5.0, 7.0])
      expect(daily[:kpis][0][:value]).to eq(12.0)
      expect(daily[:kpis][1][:value]).to eq(12.0)
      expect(daily[:kpis][2][:value]).to be_within(0.01).of(66.67)
      expect(daily[:kpis][3][:value]).to eq(5.0)
    end

    it "counts active accounts and EAs from the last 24 hours" do
      now = Time.utc(2025, 1, 10, 12, 0, 0)
      second_ea = create(:expert_advisor, name: "EA Beta", ea_id: "ea-beta")
      second_license = create(:license, user: user, expert_advisor: second_ea, status: "active")
      second_account = create(:broker_account, license: second_license, account_type: :real, account_number: 2001)

      create(:broker_account_daily_result, broker_account: real_account, result_timestamp: (now - 2.hours).to_i, result_value: 5.0)
      create(:broker_account_daily_result, broker_account: second_account, result_timestamp: (now - 3.hours).to_i, result_value: 3.0)
      create(:broker_account_daily_result, broker_account: demo_account, result_timestamp: (now - 2.days).to_i, result_value: 4.0)

      presenter = build_presenter(user: user, now: now)
      active = presenter.active_now

      expect(active[:active_accounts]).to eq(2)
      expect(active[:active_eas]).to eq(2)
      expect(active[:rows].map { |row| row[:name] }).to contain_exactly("EA Alpha", "EA Beta")
      expect(active[:chart][:labels].size).to eq(7)
    end

    it "builds expert advisor results and top EA report rows" do
      now = Time.utc(2025, 1, 3, 12, 0, 0)

      create(:broker_account_daily_result, broker_account: real_account, result_timestamp: Time.utc(2025, 1, 1, 12, 0, 0).to_i, result_value: 10.0)
      create(:broker_account_daily_result, broker_account: demo_account, result_timestamp: Time.utc(2025, 1, 2, 12, 0, 0).to_i, result_value: -4.0)
      create(:broker_account_daily_result, broker_account: real_account, result_timestamp: Time.utc(2025, 1, 3, 12, 0, 0).to_i, result_value: 3.0)
      create(:broker_account_daily_result, broker_account: real_account, result_timestamp: Time.utc(2024, 12, 31, 12, 0, 0).to_i, result_value: 4.0)

      presenter = build_presenter(user: user, filters: { from_date: "2025-01-01", to_date: "2025-01-03" }, now: now)

      ea_results = presenter.ea_results
      expect(ea_results[:labels]).to eq(["EA Alpha"])
      expect(ea_results[:datasets].map { |dataset| dataset[:label] }).to eq(
        [
          I18n.t("dashboard.broker_accounts.account_type.real"),
          I18n.t("dashboard.broker_accounts.account_type.demo")
        ]
      )
      expect(ea_results[:datasets][0][:data]).to eq([13.0])
      expect(ea_results[:datasets][1][:data]).to eq([-4.0])

      top_eas = presenter.top_eas
      row = top_eas[:rows].first
      expect(row[:name]).to eq("EA Alpha")
      expect(row[:pnl]).to eq(9.0)
      expect(row[:bar_width]).to be > 0
      expect(row[:change_percent]).to be_within(0.01).of(125.0)
    end
  end

  context "with course data" do
    let(:user) { create(:user) }

    it "limits course progress to the last 30 days" do
      now = Time.utc(2025, 2, 1, 12, 0, 0)
      recent_course = create(:course, title_en: "Recent Course", title_es: "Curso reciente")
      older_course = create(:course, title_en: "Old Course", title_es: "Curso viejo")

      create(:course_enrollment, user: user, course: recent_course, progress_percent: 40, updated_at: now - 5.days)
      create(:course_enrollment, user: user, course: older_course, progress_percent: 80, updated_at: now - 40.days)

      presenter = build_presenter(user: user, now: now)
      titles = presenter.course_progress[:rows].map { |row| row[:title] }

      expect(titles).to include("Recent Course")
      expect(titles).not_to include("Old Course")
      expect(presenter.course_status[:datasets].first[:data].sum).to eq(1)
    end

    it "builds course status, lesson progress, and study time details" do
      now = Time.utc(2025, 2, 5, 12, 0, 0)
      course = create(:course, title_en: "Risk Basics", title_es: "Riesgo Basico", category: "risk")
      course_module = create(:course_module, course: course)
      lesson = create(:course_lesson, course_module: course_module, duration_seconds: 600)

      create(:course_enrollment, user: user, course: course, progress_percent: 40, updated_at: now - 5.days)
      create(
        :course_lesson_progress,
        user: user,
        course_lesson: lesson,
        progress_seconds: 300,
        last_watched_at: now - 2.days
      )

      presenter = build_presenter(user: user, now: now)

      latest_lessons = presenter.latest_lessons
      expect(latest_lessons[:rows].first[:progress_percent]).to eq(50)

      course_status = presenter.course_status
      expect(course_status[:datasets].first[:data]).to eq([0, 1, 0])

      study_time = presenter.study_time
      expect(study_time[:labels]).to include("risk")
      expect(study_time[:datasets].first[:data].first).to eq(5.0)
    end
  end

  context "with license data" do
    let(:user) { create(:user) }

    it "builds expiring license and EA type summaries" do
      now = Time.utc(2025, 2, 10, 12, 0, 0)
      ea_robot = create(:expert_advisor, name: "EA Alpha", ea_id: "ea-alpha", ea_type: :ea_robot)
      ea_indicator = create(:expert_advisor, name: "Signal Pro", ea_id: "signal-pro", ea_type: :indicator)

      create(:license, user: user, expert_advisor: ea_robot, status: "active", expires_at: now + 10.days, trial_ends_at: nil)
      create(:license, user: user, expert_advisor: ea_indicator, status: "trial", trial_ends_at: now + 5.days, expires_at: now + 20.days)

      presenter = build_presenter(user: user, now: now)

      expiring = presenter.expiring_licenses
      expect(expiring[:rows].first[:days_remaining]).to eq(5)

      ea_types = presenter.ea_types
      expect(ea_types[:labels]).to include(
        I18n.t("dashboard.analytics.cards.ea_types.labels.ea_robot"),
        I18n.t("dashboard.analytics.cards.ea_types.labels.indicator")
      )
    end
  end

  context "without data" do
    let(:user) { create(:user) }

    it "returns empty states for analytics cards" do
      now = Time.utc(2025, 2, 15, 12, 0, 0)
      presenter = build_presenter(user: user, now: now)

      expect(presenter.daily_performance[:has_data]).to be(false)
      expect(presenter.daily_performance[:chart]).to be_nil
      expect(presenter.active_now[:has_data]).to be(false)
      expect(presenter.ea_results[:has_data]).to be(false)
      expect(presenter.course_progress[:has_data]).to be(false)
      expect(presenter.top_eas[:has_data]).to be(false)
      expect(presenter.latest_lessons[:has_data]).to be(false)
      expect(presenter.expiring_licenses[:has_data]).to be(false)
      expect(presenter.course_status[:has_data]).to be(false)
      expect(presenter.study_time[:has_data]).to be(false)
      expect(presenter.ea_types[:has_data]).to be(false)
    end
  end
end
