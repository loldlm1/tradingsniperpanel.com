require "rails_helper"

RSpec.describe BrokerAccountDailyResult, type: :model do
  it "calculates result_on in UTC" do
    timestamp = Time.utc(2025, 1, 15, 23, 59, 59).to_i
    result = build(:broker_account_daily_result, result_timestamp: timestamp)

    expect(result.result_on).to eq(Date.new(2025, 1, 15))
  end

  it "enforces one result per UTC day per broker account" do
    account = create(:broker_account)
    expert_advisor = account.license.expert_advisor
    timestamp = Time.utc(2025, 1, 15, 10, 0, 0).to_i
    create(
      :broker_account_daily_result,
      broker_account: account,
      expert_advisor: expert_advisor,
      magic_number: 123_456_789,
      result_timestamp: timestamp,
      result_value: 1.00
    )

    expect do
      create(
        :broker_account_daily_result,
        broker_account: account,
        expert_advisor: expert_advisor,
        magic_number: 123_456_789,
        result_timestamp: Time.utc(2025, 1, 15, 23, 0, 0).to_i,
        result_value: 2.00
      )
    end.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "allows same UTC day when magic_number differs" do
    account = create(:broker_account)
    expert_advisor = account.license.expert_advisor

    create(
      :broker_account_daily_result,
      broker_account: account,
      expert_advisor: expert_advisor,
      magic_number: 123_456_789,
      result_timestamp: Time.utc(2025, 1, 15, 8, 0, 0).to_i,
      result_value: 1.00
    )

    expect do
      create(
        :broker_account_daily_result,
        broker_account: account,
        expert_advisor: expert_advisor,
        magic_number: 223_456_789,
        result_timestamp: Time.utc(2025, 1, 15, 12, 0, 0).to_i,
        result_value: 2.00
      )
    end.to change(BrokerAccountDailyResult, :count).by(1)
  end

  it "groups daily totals in UTC" do
    account = create(:broker_account)
    other_account = create(:broker_account, company: "BrokerY", account_number: 5678, account_type: :demo)

    ts1 = Time.utc(2025, 1, 15, 10, 0, 0).to_i
    ts2 = Time.utc(2025, 1, 15, 18, 0, 0).to_i
    ts3 = Time.utc(2025, 1, 16, 9, 0, 0).to_i

    create(:broker_account_daily_result, broker_account: account, result_timestamp: ts1, result_value: 10.25)
    create(:broker_account_daily_result, broker_account: other_account, result_timestamp: ts2, result_value: -2.50)
    create(:broker_account_daily_result, broker_account: account, result_timestamp: ts3, result_value: 5.00)

    totals = described_class.daily_totals(from_ts: ts1, to_ts: ts3)

    expect(totals[Date.new(2025, 1, 15)]).to eq(BigDecimal("7.75"))
    expect(totals[Date.new(2025, 1, 16)]).to eq(BigDecimal("5.0"))
  end

  it "rejects oversized magic numbers" do
    result = build(:broker_account_daily_result, magic_number: Licenses::MagicNumberPolicy::MAX_VALUE + 1)

    expect(result).not_to be_valid
    expect(result.errors[:magic_number]).to include("must be less than or equal to #{Licenses::MagicNumberPolicy::MAX_VALUE}")
  end
end
