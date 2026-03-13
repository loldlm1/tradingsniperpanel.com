require "rails_helper"

RSpec.describe PartnerProfile, type: :model do
  it "generates and syncs a referral code when blank" do
    user = create(:user)

    profile = described_class.create!(
      user: user,
      referral_code: nil,
      discount_percent: 10,
      commission_percent: 20,
      payout_mode: :once_paid
    )

    expect(profile.referral_code).to be_present
    expect(user.reload.referral_codes.first.code).to eq(profile.referral_code)
  end

  it "updates the user's referral code when the profile code changes" do
    user = create(:user)
    profile = create(:partner_profile, user: user, referral_code: "PARTNER01")

    profile.update!(referral_code: "PARTNER02")

    expect(user.reload.referral_codes.first.code).to eq("PARTNER02")
    expect(Refer::ReferralCode.exists?(code: "PARTNER01")).to be(false)
  end
end
