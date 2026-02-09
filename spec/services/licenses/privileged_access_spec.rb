require "rails_helper"

RSpec.describe Licenses::PrivilegedAccess do
  let(:encoder) { Licenses::LicenseKeyEncoder.new(primary_key: "PRIMARY_KEY", secondary_key: "SECONDARY_KEY") }

  it "provisions role-based licenses for privileged users" do
    user = create(:user, :full_trader)
    ea_one = create(:expert_advisor, ea_id: "ea-role-1")
    ea_two = create(:expert_advisor, ea_id: "ea-role-2")

    expect do
      described_class.new(user: user, encoder: encoder).sync_all
    end.to change { user.licenses.count }.by(2)

    sources = user.licenses.where(expert_advisor_id: [ea_one.id, ea_two.id]).pluck(:source)
    expect(sources).to all(eq(described_class::ROLE_LICENSE_SOURCE))
    expect(user.licenses.where(source: described_class::ROLE_LICENSE_SOURCE)).to all(be_active)
  end

  it "does not override paid one-time licenses" do
    user = create(:user, :full_trader)
    expert_advisor = create(:expert_advisor, ea_id: "ea-paid")
    paid_license = create(
      :license,
      :one_time,
      user: user,
      expert_advisor: expert_advisor,
      source: "stripe_charge"
    )

    described_class.new(user: user, encoder: encoder).sync_all

    paid_license.reload
    expect(paid_license.source).to eq("stripe_charge")
    expect(paid_license).to be_active
  end

  it "revokes role-based licenses when access is removed" do
    user = create(:user, :full_trader)
    expert_advisor = create(:expert_advisor, ea_id: "ea-revoke")
    license = create(
      :license,
      :one_time,
      user: user,
      expert_advisor: expert_advisor,
      source: described_class::ROLE_LICENSE_SOURCE
    )

    user.update!(role: :trader)

    described_class.new(user: user, encoder: encoder).sync_all

    license.reload
    expect(license).to be_revoked
  end
end
