require "rails_helper"

RSpec.describe Licenses::RevokeRoleAccess do
  let(:now) { Time.utc(2026, 7, 13, 12) }

  it "revokes role-issued licenses atomically in stable ID order" do
    active = create(
      :license,
      status: "active",
      source: described_class::ROLE_LICENSE_SOURCE,
      trial_ends_at: nil,
      expires_at: 1.month.from_now
    )
    trial = create(:license, source: described_class::ROLE_LICENSE_SOURCE, trial_ends_at: 1.week.from_now)
    unrelated = create(:license, status: "active", source: "stripe_subscription", trial_ends_at: nil)

    result = described_class.new(now: now).call

    expect(result.license_ids).to eq([ active.id, trial.id ].sort)
    expect(result.revoked_at).to eq(now)
    expect(active.reload).to have_attributes(status: "revoked", trial_ends_at: nil, expires_at: now, last_synced_at: now)
    expect(trial.reload).to have_attributes(status: "revoked", trial_ends_at: nil, expires_at: now, last_synced_at: now)
    expect(unrelated.reload.status).to eq("active")
  end

  it "is idempotent when retried" do
    license = create(
      :license,
      status: "active",
      source: described_class::ROLE_LICENSE_SOURCE,
      trial_ends_at: nil,
      expires_at: 1.month.from_now
    )

    first = described_class.new(now: now).call
    first_updated_at = license.reload.updated_at
    second = described_class.new(now: now + 1.hour).call

    expect(first.license_ids).to eq([ license.id ])
    expect(second.license_ids).to eq([])
    expect(license.reload.updated_at).to eq(first_updated_at)
  end

  it "rolls back every revocation when one license update fails" do
    first = create(
      :license,
      status: "active",
      source: described_class::ROLE_LICENSE_SOURCE,
      trial_ends_at: nil,
      expires_at: 1.month.from_now
    )
    second = create(:license, source: described_class::ROLE_LICENSE_SOURCE, trial_ends_at: 1.week.from_now)

    allow_any_instance_of(License).to receive(:update!).and_wrap_original do |method, *args|
      raise ActiveRecord::RecordInvalid.new(method.receiver) if method.receiver.id == second.id

      method.call(*args)
    end

    expect { described_class.new(now: now).call }.to raise_error(ActiveRecord::RecordInvalid)
    expect(first.reload.status).to eq("active")
    expect(second.reload.status).to eq("trial")
  end

  it "makes the previous role-issued token unusable" do
    license = create(
      :license,
      status: "active",
      source: described_class::ROLE_LICENSE_SOURCE,
      trial_ends_at: nil,
      expires_at: 1.month.from_now
    )
    previous_key = license.encrypted_key

    described_class.new(now: now).call
    result = Licenses::LicenseVerifier.new.call(
      source: ENV.fetch("EA_LICENSE_SOURCE_ID", "trading_sniper_floor"),
      email: license.user.email,
      ea_id: license.expert_advisor.ea_id,
      license_key: previous_key
    )

    expect(result.ok?).to be(false)
    expect(result.error).to eq(:expired)
  end
end
