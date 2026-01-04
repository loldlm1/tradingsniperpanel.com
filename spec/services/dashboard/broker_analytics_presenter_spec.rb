require "rails_helper"

RSpec.describe Dashboard::BrokerAnalyticsPresenter do
  let(:user) { create(:user) }
  let(:expert_advisor) { create(:expert_advisor, name: "EA Alpha", ea_id: "ea-alpha") }
  let!(:license) { create(:license, user: user, expert_advisor: expert_advisor, status: "active") }
  let!(:broker_a) { create(:broker_account, license: license, company: "BrokerA", account_number: 4101, account_type: :real) }
  let!(:broker_b) { create(:broker_account, license: license, company: "BrokerB", account_number: 4102, account_type: :demo) }

  let(:from_ts) { Time.utc(2025, 1, 1, 0, 0, 0).to_i }
  let(:to_ts) { Time.utc(2025, 1, 3, 23, 59, 59).to_i }

  before do
    create(:broker_account_daily_result, broker_account: broker_a, result_timestamp: Time.utc(2025, 1, 1, 12, 0, 0).to_i, result_value: 10.00)
    create(:broker_account_daily_result, broker_account: broker_a, result_timestamp: Time.utc(2025, 1, 3, 12, 0, 0).to_i, result_value: 5.00)
    create(:broker_account_daily_result, broker_account: broker_b, result_timestamp: Time.utc(2025, 1, 1, 12, 0, 0).to_i, result_value: 2.50)
    create(:broker_account_daily_result, broker_account: broker_b, result_timestamp: Time.utc(2025, 1, 2, 12, 0, 0).to_i, result_value: -1.00)
  end

  it "fills missing days with zeros for the total chart" do
    presenter = described_class.new(user: user, filters: { from_ts: from_ts, to_ts: to_ts }).call

    expect(presenter.chart_data[:labels]).to eq(["2025-01-01", "2025-01-02", "2025-01-03"])
    expect(presenter.chart_data[:datasets].size).to eq(1)
    expect(presenter.chart_data[:datasets].first[:data]).to eq([12.5, -1.0, 5.0])
  end

  it "builds multi-series datasets when comparing by broker" do
    presenter = described_class.new(
      user: user,
      filters: { from_ts: from_ts, to_ts: to_ts, compare_by: "broker" }
    ).call

    labels = presenter.chart_data[:datasets].map { |dataset| dataset[:label] }
    expect(labels).to contain_exactly("BrokerA", "BrokerB")

    broker_a_series = presenter.chart_data[:datasets].detect { |dataset| dataset[:label] == "BrokerA" }
    broker_b_series = presenter.chart_data[:datasets].detect { |dataset| dataset[:label] == "BrokerB" }

    expect(broker_a_series[:data]).to eq([10.0, 0.0, 5.0])
    expect(broker_b_series[:data]).to eq([2.5, -1.0, 0.0])
  end
end
