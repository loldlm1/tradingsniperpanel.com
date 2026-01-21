require "rails_helper"

RSpec.describe Dashboard::AnalyticsPresenter do
  let(:user) { create(:user) }
  let(:expert_advisor) { create(:expert_advisor, name: "EA Alpha", ea_id: "ea-alpha") }
  let!(:license) { create(:license, user: user, expert_advisor: expert_advisor, status: "active") }
  let!(:real_account) { create(:broker_account, license: license, account_type: :real, account_number: 1001) }
  let!(:demo_account) { create(:broker_account, license: license, account_type: :demo, account_number: 1002) }

  def build_presenter(filters: {}, now: Time.current)
    described_class.new(user: user, filters: filters, now: now).call
  end

  it "builds daily performance totals and chart data for the selected range" do
    now = Time.utc(2025, 1, 3, 12, 0, 0)

    create(:broker_account_daily_result, broker_account: real_account, result_timestamp: Time.utc(2025, 1, 1, 12, 0, 0).to_i, result_value: 10.0)
    create(:broker_account_daily_result, broker_account: demo_account, result_timestamp: Time.utc(2025, 1, 2, 12, 0, 0).to_i, result_value: -5.0)
    create(:broker_account_daily_result, broker_account: real_account, result_timestamp: Time.utc(2025, 1, 3, 12, 0, 0).to_i, result_value: 7.0)

    presenter = build_presenter(filters: { from_date: "2025-01-01", to_date: "2025-01-03" }, now: now)
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

    presenter = build_presenter(now: now)
    active = presenter.active_now

    expect(active[:active_accounts]).to eq(2)
    expect(active[:active_eas]).to eq(2)
    expect(active[:rows].map { |row| row[:name] }).to contain_exactly("EA Alpha", "EA Beta")
    expect(active[:chart][:labels].size).to eq(7)
  end

  it "limits course progress to the last 30 days" do
    now = Time.utc(2025, 2, 1, 12, 0, 0)
    recent_course = create(:course, title_en: "Recent Course", title_es: "Curso reciente")
    older_course = create(:course, title_en: "Old Course", title_es: "Curso viejo")

    create(:course_enrollment, user: user, course: recent_course, progress_percent: 40, updated_at: now - 5.days)
    create(:course_enrollment, user: user, course: older_course, progress_percent: 80, updated_at: now - 40.days)

    presenter = build_presenter(now: now)
    titles = presenter.course_progress[:rows].map { |row| row[:title] }

    expect(titles).to include("Recent Course")
    expect(titles).not_to include("Old Course")
    expect(presenter.course_status[:datasets].first[:data].sum).to eq(1)
  end
end
