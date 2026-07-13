require "rails_helper"

RSpec.describe Licenses::LicenseKeyEncoder do
  let(:encoder) { described_class.new(primary_key: "PRIMARYKEYEXAMPLE1234567890", secondary_key: "SECONDARY_KEY") }
  let(:expires_at) { Time.utc(2025, 1, 1, 0, 0, 0) }

  it "produces deterministic uppercase hex for the same payload" do
    key1 = encoder.generate(email: "user@example.com", ea_id: "ea-alpha", expires_at:)
    key2 = encoder.generate(email: "user@example.com", ea_id: "ea-alpha", expires_at:)

    expect(key1).to eq(key2)
    expect(key1).to eq(key1.upcase)
  end

  it "decrypts back to the normalized payload with the unix expiry" do
    key = encoder.generate(email: "User@example.com", ea_id: "ea-alpha", expires_at:)

    expect(encoder.decrypt(key)).to eq("user@example.com,ea-alpha,#{expires_at.to_i}")
  end

  it "adds the positive token version for version 2 and later" do
    key = encoder.generate(
      email: "User@example.com",
      ea_id: "ea-alpha",
      expires_at: expires_at,
      token_version: 2
    )

    payload = encoder.decrypt(key).split(",")
    expect(payload.length).to eq(4)
    expect(payload.last).to eq("2")
  end

  it "changes when email or ea_id changes" do
    base_key = encoder.generate(email: "user@example.com", ea_id: "ea-alpha", expires_at:)
    other_email = encoder.generate(email: "user2@example.com", ea_id: "ea-alpha", expires_at:)
    other_ea = encoder.generate(email: "user@example.com", ea_id: "ea-beta", expires_at:)

    expect(base_key).not_to eq(other_email)
    expect(base_key).not_to eq(other_ea)
  end

  it "validates a matching key" do
    key = encoder.generate(email: "valid@example.com", ea_id: "ea-123", expires_at:)

    expect(encoder.valid_key?(license_key: key, email: "valid@example.com", ea_id: "ea-123", expires_at: expires_at)).to be(true)
    expect(encoder.valid_key?(license_key: key, email: "other@example.com", ea_id: "ea-123", expires_at: expires_at)).to be(false)
  end

  it "validates against the supplied token version" do
    key = encoder.generate(email: "valid@example.com", ea_id: "ea-123", expires_at:, token_version: 2)

    expect(
      encoder.valid_key?(
        license_key: key,
        email: "valid@example.com",
        ea_id: "ea-123",
        expires_at: expires_at,
        token_version: 2
      )
    ).to be(true)
    expect(
      encoder.valid_key?(
        license_key: key,
        email: "valid@example.com",
        ea_id: "ea-123",
        expires_at: expires_at,
        token_version: 1
      )
    ).to be(false)
  end

  it "rejects invalid token versions" do
    expect do
      encoder.generate(email: "valid@example.com", ea_id: "ea-123", expires_at:, token_version: 0)
    end.to raise_error(ArgumentError, "token_version must be a positive integer")

    expect do
      encoder.generate(email: "valid@example.com", ea_id: "ea-123", expires_at:, token_version: "2")
    end.to raise_error(ArgumentError, "token_version must be a positive integer")
  end
end
