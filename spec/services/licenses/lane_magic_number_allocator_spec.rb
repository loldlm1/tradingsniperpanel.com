require "rails_helper"

RSpec.describe Licenses::LaneMagicNumberAllocator do
  let(:license) { create(:license, :one_time) }
  let(:source) { ENV.fetch("EA_LICENSE_SOURCE_ID", "trading_sniper_floor") }
  let(:email) { license.user.email }
  let(:broker_account) do
    {
      company: "BrokerX",
      account_number: 123_456,
      account_type: "real"
    }
  end

  it "creates a positive magic number for a new lane" do
    result = described_class.new(
      license: license,
      source: source,
      email: email,
      broker_account: broker_account
    ).call

    expect(result).to be_ok
    expect(result.magic_number).to be > 0

    lane = LicenseLaneMagicNumber.find_by!(
      license_id: license.id,
      source: source,
      email: email,
      company: "brokerx",
      account_number: 123_456,
      account_type: "real"
    )
    expect(lane.magic_number).to eq(result.magic_number)
  end

  it "returns the same magic number for the same lane" do
    first = described_class.new(
      license: license,
      source: source,
      email: email,
      broker_account: broker_account
    ).call

    second = described_class.new(
      license: license,
      source: source,
      email: email,
      broker_account: broker_account
    ).call

    expect(first).to be_ok
    expect(second).to be_ok
    expect(second.magic_number).to eq(first.magic_number)
    expect(LicenseLaneMagicNumber.count).to eq(1)
  end

  it "creates different lane magic numbers for different EAs" do
    other_license = create(:license, :one_time, user: license.user)

    first = described_class.new(
      license: license,
      source: source,
      email: email,
      broker_account: broker_account
    ).call

    second = described_class.new(
      license: other_license,
      source: source,
      email: email,
      broker_account: broker_account
    ).call

    expect(first).to be_ok
    expect(second).to be_ok
    expect(second.magic_number).not_to eq(first.magic_number)
  end

  it "rejects invalid broker payloads" do
    result = described_class.new(
      license: license,
      source: source,
      email: email,
      broker_account: { company: "", account_number: "abc", account_type: "real" }
    ).call

    expect(result).not_to be_ok
    expect(result.error).to eq(:invalid_payload)
    expect(result.code).to eq(:unprocessable_content)
  end
end
