require "rails_helper"
require "digest"

RSpec.describe Licenses::RotateTokens do
  let(:encoder) do
    Licenses::LicenseKeyEncoder.new(
      primary_key: ENV["EA_LICENSE_PRIMARY_KEY"],
      secondary_key: ENV["EA_LICENSE_SECRET_KEY"]
    )
  end
  let(:verifier) { Licenses::LicenseVerifier.new(encoder:) }
  let(:source_id) { ENV.fetch("EA_LICENSE_SOURCE_ID", "trading_sniper_floor") }

  it "invalidates the previous token and accepts the rotated token" do
    license = create(:license, status: "active", trial_ends_at: nil, expires_at: 1.month.from_now)
    previous_key = license.encrypted_key

    result = described_class.new(scope: :user, user: license.user, encoder: encoder).call
    license.reload

    expect(result.license_ids).to eq([ license.id ])
    expect(license.token_version).to eq(2)
    expect(license.token_rotated_at).to be_present
    expect(Digest::SHA256.hexdigest(license.encrypted_key)).not_to eq(Digest::SHA256.hexdigest(previous_key))

    stale_result = verify(license, previous_key)
    current_result = verify(license, license.encrypted_key)
    expect(stale_result.error).to eq(:invalid_key)
    expect(current_result.ok?).to be(true)
  end

  it "increments the version on every rotation" do
    license = create(:license, status: "active", trial_ends_at: nil, expires_at: 1.month.from_now)

    2.times { described_class.new(scope: :user, user: license.user, encoder: encoder).call }

    expect(license.reload.token_version).to eq(3)
  end

  it "rotates every active or trial license atomically in stable ID order" do
    active = create(:license, status: "active", trial_ends_at: nil, expires_at: 1.month.from_now)
    trial = create(:license, status: "trial", trial_ends_at: 1.week.from_now)
    expired = create(:license, status: "expired", trial_ends_at: nil, expires_at: 1.day.ago)

    result = described_class.new(scope: :all, encoder: encoder).call

    expect(result.license_ids).to eq([ active.id, trial.id ].sort)
    expect(active.reload.token_version).to eq(2)
    expect(trial.reload.token_version).to eq(2)
    expect(expired.reload.token_version).to eq(1)
  end

  it "rolls back every license when any key generation fails" do
    first = create(:license, status: "active", trial_ends_at: nil, expires_at: 1.month.from_now)
    second = create(:license, status: "trial", trial_ends_at: 1.week.from_now)
    original_digests = [ first, second ].to_h do |license|
      [ license.id, Digest::SHA256.hexdigest(license.encrypted_key) ]
    end
    failing_encoder = instance_double(Licenses::LicenseKeyEncoder, configured?: true)
    allow(failing_encoder).to receive(:generate).and_return("ROTATED").and_raise(ArgumentError, "generation failed")

    expect do
      described_class.new(scope: :all, encoder: failing_encoder).call
    end.to raise_error(ArgumentError, "generation failed")

    [ first, second ].each do |license|
      license.reload
      expect(license.token_version).to eq(1)
      expect(Digest::SHA256.hexdigest(license.encrypted_key)).to eq(original_digests.fetch(license.id))
    end
  end

  it "limits user rotation to that user's subscription licenses" do
    user = create(:user)
    subscription_license = create(:license, user: user, status: "active", trial_ends_at: nil, expires_at: 1.month.from_now)
    one_time_license = create(:license, :one_time, user: user)
    other_license = create(:license, status: "active", trial_ends_at: nil, expires_at: 1.month.from_now)

    result = described_class.new(scope: :user, user: user, encoder: encoder).call

    expect(result.license_ids).to eq([ subscription_license.id ])
    expect(subscription_license.reload.token_version).to eq(2)
    expect(one_time_license.reload.token_version).to eq(1)
    expect(other_license.reload.token_version).to eq(1)
  end

  it "requires an explicit valid scope" do
    expect { described_class.new(scope: :unknown, encoder: encoder) }
      .to raise_error(ArgumentError, "scope must be :all or :user")
    expect { described_class.new(scope: :user, encoder: encoder) }
      .to raise_error(ArgumentError, "user is required for user rotation")
  end

  def verify(license, key)
    verifier.call(
      source: source_id,
      email: license.user.email,
      ea_id: license.expert_advisor.ea_id,
      license_key: key
    )
  end
end
