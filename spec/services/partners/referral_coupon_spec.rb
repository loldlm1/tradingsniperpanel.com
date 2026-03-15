require "rails_helper"

RSpec.describe Partners::ReferralCoupon do
  let(:partner_profile) { create(:partner_profile, stripe_coupon_id: nil, discount_percent: 10) }

  around do |example|
    Rails.cache.clear
    with_stripe_key { example.run }
    Rails.cache.clear
  end

  it "creates first-invoice-only referral coupons" do
    coupon = instance_double(Stripe::Coupon, id: "coupon_once", percent_off: 10, duration: "once", metadata: {})
    allow(Stripe::Coupon).to receive(:list).and_return(double(data: []))

    expect(Stripe::Coupon).to receive(:create).with(hash_including(percent_off: 10, duration: "once")).and_return(coupon)

    result = described_class.new(partner_profile: partner_profile, percent: 10).coupon_id

    expect(result).to eq("coupon_once")
    expect(partner_profile.reload.stripe_coupon_id).to eq("coupon_once")
  end

  it "replaces mismatched legacy recurring coupons" do
    partner_profile.update!(stripe_coupon_id: "coupon_forever")
    recurring_coupon = instance_double(
      Stripe::Coupon,
      id: "coupon_forever",
      percent_off: 10,
      duration: "forever",
      metadata: { "kind" => "referral_partner", "partner_profile_id" => partner_profile.id.to_s }
    )
    replacement_coupon = instance_double(Stripe::Coupon, id: "coupon_once", percent_off: 10, duration: "once", metadata: {})

    allow(Stripe::Coupon).to receive(:retrieve).with("coupon_forever").and_return(recurring_coupon)
    allow(Stripe::Coupon).to receive(:list).and_return(double(data: [recurring_coupon]))
    expect(Stripe::Coupon).to receive(:create).with(hash_including(percent_off: 10, duration: "once")).and_return(replacement_coupon)

    result = described_class.new(partner_profile: partner_profile, percent: 10).coupon_id

    expect(result).to eq("coupon_once")
    expect(partner_profile.reload.stripe_coupon_id).to eq("coupon_once")
  end
end
