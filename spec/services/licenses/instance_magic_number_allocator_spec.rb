require "rails_helper"

RSpec.describe Licenses::InstanceMagicNumberAllocator do
  let(:license) { create(:license, :one_time) }
  let(:source) { ENV.fetch("EA_LICENSE_SOURCE_ID", "trading_sniper_floor") }
  let(:email) { license.user.email }
  let(:broker_account) do
    create(
      :broker_account,
      license: license,
      company: "BrokerX",
      account_number: 123_456,
      account_type: :real
    )
  end
  let(:instance_id) { "pandora_box_ABC123" }

  it "creates a stable positive magic number for a new instance" do
    result = described_class.new(
      license: license,
      source: source,
      email: email,
      broker_account: broker_account,
      instance_id: instance_id
    ).call

    expect(result).to be_ok
    expect(result.magic_number).to be > 0
    expect(result.magic_number).to be <= Licenses::MagicNumberPolicy::MAX_VALUE

    record = LicenseInstanceMagicNumber.find_by!(
      broker_account_id: broker_account.id,
      expert_advisor_id: license.expert_advisor_id,
      instance_id: instance_id
    )
    expect(record.magic_number).to eq(result.magic_number)
    expect(record.source).to eq(source)
    expect(record.email).to eq(email)
  end

  it "returns the same magic number and refreshes last seen for the same instance" do
    first_seen_at = Time.zone.local(2026, 6, 3, 10, 0, 0)
    last_seen_at = first_seen_at + 5.minutes

    first = described_class.new(
      license: license,
      source: source,
      email: email,
      broker_account: broker_account,
      instance_id: instance_id,
      now: first_seen_at
    ).call

    second = described_class.new(
      license: license,
      source: source,
      email: email.upcase,
      broker_account: broker_account,
      instance_id: " #{instance_id} ",
      now: last_seen_at
    ).call

    expect(first).to be_ok
    expect(second).to be_ok
    expect(second.magic_number).to eq(first.magic_number)
    expect(LicenseInstanceMagicNumber.count).to eq(1)

    record = LicenseInstanceMagicNumber.first
    expect(record.first_seen_at.to_i).to eq(first_seen_at.to_i)
    expect(record.last_seen_at.to_i).to eq(last_seen_at.to_i)
    expect(record.email).to eq(email)
  end

  it "creates different magic numbers for different instances on the same broker account" do
    first = described_class.new(
      license: license,
      source: source,
      email: email,
      broker_account: broker_account,
      instance_id: "pandora_box_A"
    ).call

    second = described_class.new(
      license: license,
      source: source,
      email: email,
      broker_account: broker_account,
      instance_id: "pandora_box_B"
    ).call

    expect(first).to be_ok
    expect(second).to be_ok
    expect(second.magic_number).not_to eq(first.magic_number)
    expect(LicenseInstanceMagicNumber.count).to eq(2)
  end

  it "does not collide across different EAs on the same broker account" do
    first = described_class.new(
      license: license,
      source: source,
      email: email,
      broker_account: broker_account,
      instance_id: "pandora_box_A"
    ).call
    other_license = create(:license, :one_time, user: license.user)
    broker_account.update!(license: other_license)

    second = described_class.new(
      license: other_license,
      source: source,
      email: email,
      broker_account: broker_account,
      instance_id: "other_ea_A"
    ).call

    expect(first).to be_ok
    expect(second).to be_ok
    expect(second.magic_number).not_to eq(first.magic_number)
  end

  it "avoids legacy lane magic on the same broker identity" do
    legacy_lane = create(
      :license_lane_magic_number,
      license: license,
      source: source,
      email: email,
      company: broker_account.company,
      account_number: broker_account.account_number,
      account_type: broker_account.account_type,
      magic_number: 888_888_888
    )
    allow(Licenses::MagicNumberPolicy).to receive(:generate).and_return(legacy_lane.magic_number, 777_777_777)

    result = described_class.new(
      license: license,
      source: source,
      email: email,
      broker_account: broker_account,
      instance_id: instance_id
    ).call

    expect(result).to be_ok
    expect(result.magic_number).to eq(777_777_777)
  end

  it "rejects broker accounts not currently bound to the license" do
    other_license = create(:license, :one_time)

    result = described_class.new(
      license: other_license,
      source: source,
      email: email,
      broker_account: broker_account,
      instance_id: instance_id
    ).call

    expect(result).not_to be_ok
    expect(result.error).to eq(:invalid_payload)
    expect(result.code).to eq(:unprocessable_content)
  end

  it "rejects missing and invalid instance ids" do
    missing = described_class.new(
      license: license,
      source: source,
      email: email,
      broker_account: broker_account,
      instance_id: " "
    ).call
    invalid = described_class.new(
      license: license,
      source: source,
      email: email,
      broker_account: broker_account,
      instance_id: "bad value!"
    ).call

    expect(missing.error).to eq(:missing_instance_id)
    expect(missing.code).to eq(:unprocessable_content)
    expect(invalid.error).to eq(:invalid_instance_id)
    expect(invalid.code).to eq(:unprocessable_content)
  end

  it "remaps an oversized manually inserted instance magic number" do
    record = create(
      :license_instance_magic_number,
      license: license,
      broker_account: broker_account,
      expert_advisor: license.expert_advisor,
      instance_id: instance_id,
      magic_number: 123_456_789
    )
    previous_magic_number = Licenses::MagicNumberPolicy::MAX_VALUE + 1
    record.update_columns(magic_number: previous_magic_number)
    allow(Licenses::MagicNumberPolicy).to receive(:generate).and_return(456_456_456)

    result = described_class.new(
      license: license,
      source: source,
      email: email,
      broker_account: broker_account,
      instance_id: instance_id
    ).call

    expect(result).to be_ok
    expect(result.magic_number).to eq(456_456_456)
    expect(record.reload.magic_number).to eq(456_456_456)
    expect(record.magic_number).not_to eq(previous_magic_number)
  end
end
