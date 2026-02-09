require "rails_helper"

RSpec.describe Access::PrivilegedRolePolicy do
  it "returns true for admin, master admin, and full trader roles" do
    expect(described_class.full_access?(create(:user, :admin))).to be(true)
    expect(described_class.full_access?(create(:user, :master_admin))).to be(true)
    expect(described_class.full_access?(create(:user, :full_trader))).to be(true)
  end

  it "returns false for non-privileged roles" do
    expect(described_class.full_access?(create(:user))).to be(false)
    expect(described_class.full_access?(create(:user, :partner))).to be(false)
    expect(described_class.full_access?(nil)).to be(false)
  end
end
