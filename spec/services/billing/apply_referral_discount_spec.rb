require "rails_helper"

RSpec.describe Billing::ApplyReferralDiscount do
  let(:checkout_params) do
    {
      mode: "subscription",
      line_items: [{ price: "price_123", quantity: 1 }],
      allow_promotion_codes: true
    }
  end

  let(:referrer) { create(:user) }
  let(:coupon_service) { instance_double(Partners::ReferralCoupon, coupon_id: "coupon_123") }

  before do
    allow(Partners::ReferralCoupon).to receive(:new).and_return(coupon_service)
  end

  it "adds a coupon and metadata for referred users" do
    referred_user = create(:user)
    create(:partner_profile, user: referrer, referral_code: "PARTNER10", discount_percent: 10)
    Referrals::AttachReferrer.new(user: referred_user, code: "PARTNER10").call
    referred_user.reload
    expect(referred_user.referrer).to eq(referrer)

    result = described_class.new(user: referred_user, checkout_params: checkout_params).call

    expect(result[:discounts]).to eq([{ coupon: "coupon_123" }])
    expect(result).not_to have_key(:allow_promotion_codes)
    expect(result[:subscription_data][:metadata]["referrer_id"]).to eq(referrer.id.to_s)
    expect(result[:subscription_data][:metadata]["referral_code"]).to eq("PARTNER10")
    expect(result[:subscription_data][:metadata]["partner_referral_code"]).to eq("PARTNER10")
  end

  it "returns original params once the referral has been completed" do
    referred_user = create(:user)
    create(:partner_profile, user: referrer, referral_code: "PARTNER10", discount_percent: 10)
    Referrals::AttachReferrer.new(user: referred_user, code: "PARTNER10").call
    Referrals::MarkCompleted.new(user: referred_user).call

    expect(Partners::ReferralCoupon).not_to receive(:new)

    result = described_class.new(user: referred_user, checkout_params: checkout_params).call

    expect(result).to eq(checkout_params)
  end

  it "returns original params when not referred" do
    user = create(:user)

    result = described_class.new(user:, checkout_params: checkout_params).call

    expect(result).to eq(checkout_params)
  end
end
