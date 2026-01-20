require "rails_helper"

RSpec.describe Dashboard::MainPresenter do
  include ActiveSupport::Testing::TimeHelpers

  let(:user) { create(:user) }
  let(:plan_context) { {} }

  after { travel_back }

  def build_presenter(now: Time.current, subscription: nil)
    described_class.new(
      user: user,
      subscription: subscription,
      plan_context: plan_context,
      now: now
    ).call
  end

  it "returns empty charts when there is no broker data" do
    travel_to(Time.utc(2026, 4, 30, 12, 0, 0)) do
      presenter = build_presenter(now: Time.current)

      expect(presenter.pnl_summary[:chart]).to be_nil
      expect(presenter.balance_distribution[:chart]).to be_nil
      expect(presenter.balance_distribution[:legend]).to be_empty
      expect(presenter.course_progress_card[:progress_percent]).to be_nil
      expect(presenter.licenses_card[:active_count]).to eq(0)
      expect(presenter.mini_cards.map { |card| card[:total] }).to all(eq(0))
    end
  end

  it "builds charts and summaries from broker results" do
    travel_to(Time.utc(2026, 4, 30, 12, 0, 0)) do
      ea1 = create(:expert_advisor, name: "Alpha")
      ea2 = create(:expert_advisor, name: "Bravo")
      ea3 = create(:expert_advisor, name: "Charlie")

      license1 = create(:license, user: user, expert_advisor: ea1, status: "active", trial_ends_at: nil)
      license2 = create(:license, user: user, expert_advisor: ea2, status: "active", trial_ends_at: nil)
      license3 = create(:license, user: user, expert_advisor: ea3, status: "trial")

      accounts = [
        create(:broker_account, license: license1, company: "BrokerA", account_number: 1001),
        create(:broker_account, license: license1, company: "BrokerB", account_number: 1002),
        create(:broker_account, license: license2, company: "BrokerC", account_number: 2001),
        create(:broker_account, license: license2, company: "BrokerD", account_number: 2002),
        create(:broker_account, license: license3, company: "BrokerE", account_number: 3001),
        create(:broker_account, license: license3, company: "BrokerF", account_number: 3002)
      ]

      values = [100, 200, 150, 50, 60, 40]
      accounts.each_with_index do |account, index|
        create(
          :broker_account_daily_result,
          broker_account: account,
          result_timestamp: Time.current.to_i,
          result_value: values[index]
        )
      end

      course = create(:course, title_en: "Risk Management", title_es: "Gestion de riesgo")
      create(:course_enrollment, user: user, course: course, progress_percent: 65)

      presenter = build_presenter(now: Time.current)

      pnl = presenter.pnl_summary
      total = ActionController::Base.helpers.number_to_currency(600, unit: "$", precision: 2)
      average = ActionController::Base.helpers.number_to_currency(20, unit: "$", precision: 2)

      expect(pnl[:total]).to eq(total)
      expect(pnl[:average]).to eq(average)
      expect(pnl[:chart][:datasets].map { |dataset| dataset[:label] }).to eq(["Alpha", "Bravo", "Charlie"])

      balance = presenter.balance_distribution
      expect(balance[:legend].size).to eq(6)
      expect(balance[:legend].last[:label]).to eq(I18n.t("dashboard.main.balance_card.other"))
      expect(balance[:legend].last[:value]).to eq(40.0)

      licenses = presenter.licenses_card
      expect(licenses[:active_count]).to eq(3)
      expect(licenses[:trial_count]).to eq(1)

      course_progress = presenter.course_progress_card
      expect(course_progress[:progress_percent]).to eq(65)
      expect(course_progress[:course_title]).to eq("Risk Management")

      summary_rows = presenter.account_summary_rows
      expect(summary_rows.size).to eq(3)
      expect(summary_rows.first[:total_accounts]).to eq(2)
      expect(summary_rows.first[:name]).to eq("Alpha")
    end
  end
end
