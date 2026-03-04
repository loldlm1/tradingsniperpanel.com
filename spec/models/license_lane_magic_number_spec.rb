require "rails_helper"

RSpec.describe LicenseLaneMagicNumber, type: :model do
  it "normalizes source, email, and company" do
    lane = build(
      :license_lane_magic_number,
      source: " Trading_Sniper_Floor ",
      email: " User@Example.COM ",
      company: "  BrokerX  "
    )

    lane.validate

    expect(lane.source).to eq("trading_sniper_floor")
    expect(lane.email).to eq("user@example.com")
    expect(lane.company).to eq("brokerx")
  end

  it "dedupes lanes by license + identity" do
    license = create(:license)

    create(
      :license_lane_magic_number,
      license: license,
      source: "trading_sniper_floor",
      email: license.user.email,
      company: "brokerx",
      account_number: 123_456,
      account_type: "real",
      magic_number: 123_456_789
    )

    duplicate = build(
      :license_lane_magic_number,
      license: license,
      source: "trading_sniper_floor",
      email: license.user.email,
      company: "BrokerX",
      account_number: 123_456,
      account_type: "real",
      magic_number: 223_456_789
    )

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:account_number]).to include("has already been taken")
  end
end
