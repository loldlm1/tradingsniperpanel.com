require "rails_helper"

RSpec.describe LicenseInstanceMagicNumber, type: :model do
  it "normalizes source, email, and surrounding instance id whitespace" do
    record = build(
      :license_instance_magic_number,
      source: " Trading_Sniper_Floor ",
      email: " User@Example.COM ",
      instance_id: "  pandora_box_ABC123  "
    )

    record.validate

    expect(record.source).to eq("trading_sniper_floor")
    expect(record.email).to eq("user@example.com")
    expect(record.instance_id).to eq("pandora_box_ABC123")
  end

  it "validates instance id format and length" do
    invalid_format = build(:license_instance_magic_number, instance_id: "bad value!")
    too_long = build(:license_instance_magic_number, instance_id: "a" * 65)

    expect(invalid_format).not_to be_valid
    expect(invalid_format.errors[:instance_id]).to include("is invalid")

    expect(too_long).not_to be_valid
    expect(too_long.errors[:instance_id]).to include("is too long (maximum is 64 characters)")
  end

  it "dedupes instance ids by broker account and expert advisor" do
    existing = create(:license_instance_magic_number, instance_id: "pandora_box_A")

    duplicate = build(
      :license_instance_magic_number,
      license: existing.license,
      broker_account: existing.broker_account,
      expert_advisor: existing.expert_advisor,
      instance_id: "pandora_box_A",
      magic_number: existing.magic_number + 10
    )

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:instance_id]).to include("has already been taken")
  end

  it "allows the same instance id on a different broker account" do
    existing = create(:license_instance_magic_number, instance_id: "pandora_box_A")
    other_license = create(:license, :one_time, expert_advisor: existing.expert_advisor)
    other_broker = create(
      :broker_account,
      license: other_license,
      company: "OtherBroker",
      account_number: 456_789
    )

    record = build(
      :license_instance_magic_number,
      license: other_license,
      broker_account: other_broker,
      expert_advisor: existing.expert_advisor,
      instance_id: existing.instance_id,
      magic_number: existing.magic_number
    )

    expect(record).to be_valid
  end

  it "rejects duplicate magic numbers on the same broker account" do
    existing = create(:license_instance_magic_number)

    duplicate = build(
      :license_instance_magic_number,
      license: existing.license,
      broker_account: existing.broker_account,
      expert_advisor: existing.expert_advisor,
      instance_id: "different_instance",
      magic_number: existing.magic_number
    )

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:magic_number]).to include("has already been taken")
  end

  it "rejects oversized magic numbers" do
    record = build(:license_instance_magic_number, magic_number: Licenses::MagicNumberPolicy::MAX_VALUE + 1)

    expect(record).not_to be_valid
    expect(record.errors[:magic_number]).to include("must be less than or equal to #{Licenses::MagicNumberPolicy::MAX_VALUE}")
  end

  it "requires the expert advisor to match the license" do
    license = create(:license, :one_time)
    other_expert_advisor = create(:expert_advisor)

    record = build(:license_instance_magic_number, license: license, expert_advisor: other_expert_advisor)

    expect(record).not_to be_valid
    expect(record.errors[:expert_advisor]).to include("is invalid")
  end
end
