require "rails_helper"

RSpec.describe Referrals::AttachReferrer do
  it "keeps the first attached partner referral" do
    first_referrer = create(:user)
    second_referrer = create(:user)
    first_profile = create(:partner_profile, user: first_referrer, referral_code: "PARTNER01")
    create(:partner_profile, user: second_referrer, referral_code: "PARTNER02")
    referred_user = create(:user)

    described_class.new(user: referred_user, code: "PARTNER01").call
    described_class.new(user: referred_user, code: "PARTNER02").call

    expect(referred_user.reload.referrer).to eq(first_referrer)
    expect(PartnerMembership.active.find_by(user: referred_user)&.partner_profile).to eq(first_profile)
  end

  it "does not create duplicate active memberships when the same referral code is reused" do
    referrer = create(:user)
    create(:partner_profile, user: referrer, referral_code: "PARTNER03")
    referred_user = create(:user)

    described_class.new(user: referred_user, code: "PARTNER03").call

    expect do
      described_class.new(user: referred_user, code: "PARTNER03").call
    end.not_to change { PartnerMembership.active.where(user: referred_user).count }
  end
end
