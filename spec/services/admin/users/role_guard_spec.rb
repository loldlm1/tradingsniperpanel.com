require "rails_helper"

RSpec.describe Admin::Users::RoleGuard do
  describe "#visible_scope" do
    it "hides master_admin users from admins" do
      admin = create(:user, :admin)
      master_admin = create(:user, :master_admin)

      guard = described_class.new(actor: admin)
      scope = guard.visible_scope(User.all)

      expect(scope).not_to include(master_admin)
    end

    it "includes master_admin users for master admins" do
      master_admin = create(:user, :master_admin)

      guard = described_class.new(actor: master_admin)
      scope = guard.visible_scope(User.all)

      expect(scope).to include(master_admin)
    end
  end

  describe "#assignable_roles_for" do
    it "limits non-master admins to non-admin roles" do
      admin = create(:user, :admin)
      trader = create(:user)

      guard = described_class.new(actor: admin)
      roles = guard.assignable_roles_for(record: trader)

      expect(roles).to match_array(%w[trader partner])
    end

    it "prevents non-master admins from changing admin roles" do
      admin = create(:user, :admin)
      target = create(:user, :admin)

      guard = described_class.new(actor: admin)
      roles = guard.assignable_roles_for(record: target)

      expect(roles).to be_empty
    end
  end

  describe "#allow_role_change?" do
    it "blocks admin role assignment for non-master admins" do
      admin = create(:user, :admin)
      trader = create(:user)

      guard = described_class.new(actor: admin)

      expect(guard.allow_role_change?(record: trader, new_role: "admin")).to be(false)
    end

    it "allows master admins to assign admin roles" do
      master_admin = create(:user, :master_admin)
      trader = create(:user)

      guard = described_class.new(actor: master_admin)

      expect(guard.allow_role_change?(record: trader, new_role: "admin")).to be(true)
    end
  end
end
