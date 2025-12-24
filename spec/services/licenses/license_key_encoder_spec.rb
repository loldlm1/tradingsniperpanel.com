require "rails_helper"

RSpec.describe Licenses::LicenseKeyEncoder do
  let(:encoder) { described_class.new(primary_key: "PRIMARYKEYEXAMPLE1234567890", secondary_key: "SECONDARY_KEY") }

  it "produces deterministic uppercase hex for the same payload" do
    key1 = encoder.generate(email: "user@example.com", ea_id: "ea-alpha")
    key2 = encoder.generate(email: "user@example.com", ea_id: "ea-alpha")

    expect(key1).to eq(key2)
    expect(key1).to eq(key1.upcase)
  end

  it "decrypts back to the normalized payload with the static days marker" do
    key = encoder.generate(email: "User@example.com", ea_id: "ea-alpha")

    expect(encoder.decrypt(key)).to eq("user@example.com,ea-alpha,34")
  end

  it "changes when email or ea_id changes" do
    base_key = encoder.generate(email: "user@example.com", ea_id: "ea-alpha")
    other_email = encoder.generate(email: "user2@example.com", ea_id: "ea-alpha")
    other_ea = encoder.generate(email: "user@example.com", ea_id: "ea-beta")

    expect(base_key).not_to eq(other_email)
    expect(base_key).not_to eq(other_ea)
  end

  it "validates a matching key" do
    key = encoder.generate(email: "valid@example.com", ea_id: "ea-123")

    expect(encoder.valid_key?(license_key: key, email: "valid@example.com", ea_id: "ea-123")).to be(true)
    expect(encoder.valid_key?(license_key: key, email: "other@example.com", ea_id: "ea-123")).to be(false)
  end
end
