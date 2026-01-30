require "rails_helper"

RSpec.describe Admin::Users::RoleGuard do
  describe "#visible_scope" do
    it "includes master_admin users for admins" do
      admin = create(:user, :admin)
      master_admin = create(:user, :master_admin)

      guard = described_class.new(actor: admin)
      scope = guard.visible_scope(User.all)

      expect(scope).to include(master_admin)
    end

    it "includes master_admin users for master admins" do
      master_admin = create(:user, :master_admin)

      guard = described_class.new(actor: master_admin)
      scope = guard.visible_scope(User.all)

      expect(scope).to include(master_admin)
    end
  end

  describe "#assignable_roles_for" do
    it "returns no assignable roles for admins" do
      admin = create(:user, :admin)
      trader = create(:user)

      guard = described_class.new(actor: admin)
      roles = guard.assignable_roles_for(record: trader)

      expect(roles).to be_empty
    end

    it "allows master admins to assign any roles" do
      master_admin = create(:user, :master_admin)
      trader = create(:user)

      guard = described_class.new(actor: master_admin)
      roles = guard.assignable_roles_for(record: trader)

      expect(roles).to match_array(User.roles.keys)
    end
  end

  describe "#allow_role_change?" do
    it "blocks role changes for admins" do
      admin = create(:user, :admin)
      trader = create(:user)

      guard = described_class.new(actor: admin)

      expect(guard.allow_role_change?(record: trader, new_role: "partner")).to be(false)
    end

    it "allows master admins to assign admin roles" do
      master_admin = create(:user, :master_admin)
      trader = create(:user)

      guard = described_class.new(actor: master_admin)

      expect(guard.allow_role_change?(record: trader, new_role: "admin")).to be(true)
    end
  end

  describe "#can_access_record?" do
    it "allows admins to access master admin records" do
      admin = create(:user, :admin)
      master_admin = create(:user, :master_admin)

      guard = described_class.new(actor: admin)

      expect(guard.can_access_record?(master_admin)).to be(true)
    end

    it "allows master admins to access master admin records" do
      master_admin = create(:user, :master_admin)

      guard = described_class.new(actor: master_admin)

      expect(guard.can_access_record?(master_admin)).to be(true)
    end
  end
end
