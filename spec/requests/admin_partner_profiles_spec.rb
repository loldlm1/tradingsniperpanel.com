require "rails_helper"

RSpec.describe "Admin partner profiles", type: :request do
  it "allows admins to create partner profiles without changing the user role" do
    admin = create(:user, :admin)
    user = create(:user, role: :trader)
    sign_in admin, scope: :user

    post admin_partner_profiles_path, params: {
      partner_profile: {
        user_id: user.id,
        active: true,
        referral_code: "PARTNER90",
        discount_percent: 10,
        commission_percent: 20,
        payout_mode: "once_paid"
      }
    }

    expect(response).to redirect_to(admin_partner_profile_path(PartnerProfile.last))
    expect(PartnerProfile.last.user).to eq(user)
    expect(PartnerProfile.last.referral_code).to eq("PARTNER90")
    expect(user.reload.role).to eq("trader")
  end

  it "allows master admins to update the partner referral code" do
    master_admin = create(:user, :master_admin)
    profile = create(:partner_profile, referral_code: "PARTNER91")
    sign_in master_admin, scope: :user

    patch admin_partner_profile_path(profile), params: {
      partner_profile: {
        referral_code: "PARTNER92",
        discount_percent: 10,
        commission_percent: 20,
        payout_mode: "once_paid",
        active: true
      }
    }

    expect(response).to redirect_to(admin_partner_profile_path(profile))
    expect(profile.reload.referral_code).to eq("PARTNER92")
  end
end
