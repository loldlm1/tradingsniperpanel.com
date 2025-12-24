require "rails_helper"

RSpec.describe Licenses::LicenseVerifier do
  let(:encoder) { Licenses::LicenseKeyEncoder.new(primary_key: ENV["EA_LICENSE_PRIMARY_KEY"], secondary_key: ENV["EA_LICENSE_SECRET_KEY"]) }
  let(:verifier) { described_class.new(encoder:, expected_source: "trading_sniper_ea") }
  let(:user) { create(:user, email: "trader@example.com") }
  let(:expert_advisor) { create(:expert_advisor, ea_id: "ea-test") }
  let(:expires_at) { 7.days.from_now }
  let(:license_key) { encoder.generate(email: user.email, ea_id: expert_advisor.ea_id, expires_at:) }
  let!(:license) do
    create(
      :license,
      user:,
      expert_advisor:,
      status: "active",
      trial_ends_at: 3.days.from_now,
      expires_at: expires_at,
      encrypted_key: license_key
    )
  end

  it "returns success for a valid license" do
    result = verifier.call(
      source: "trading_sniper_ea",
      email: user.email,
      ea_id: expert_advisor.ea_id,
      license_key:
    )

    expect(result.ok?).to be(true)
    expect(result.plan_interval).to eq(license.plan_interval)
    expect(result.trial).to eq(false)
  end

  it "rejects an invalid source" do
    result = verifier.call(
      source: "unknown_source",
      email: user.email,
      ea_id: expert_advisor.ea_id,
      license_key:
    )

    expect(result.ok?).to be(false)
    expect(result.code).to eq(:unauthorized)
  end

  it "rejects expired trial licenses" do
    license.update!(status: "trial", trial_ends_at: 1.day.ago)

    result = verifier.call(
      source: "trading_sniper_ea",
      email: user.email,
      ea_id: expert_advisor.ea_id,
      license_key:
    )

    expect(result.ok?).to be(false)
    expect(result.code).to eq(:unprocessable_entity)
    expect(result.error).to eq(:expired)
  end

  it "rejects mismatched license keys" do
    result = verifier.call(
      source: "trading_sniper_ea",
      email: user.email,
      ea_id: expert_advisor.ea_id,
      license_key: "BADKEY"
    )

    expect(result.ok?).to be(false)
    expect(result.error).to eq(:invalid_key)
  end
end
