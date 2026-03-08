require "rails_helper"

RSpec.describe Billing::StripePromotionCodeSync do
  around do |example|
    original_env = ENV["STRIPE_PRIVATE_KEY"]
    ENV["STRIPE_PRIVATE_KEY"] = "sk_test_123"
    example.run
  ensure
    ENV["STRIPE_PRIVATE_KEY"] = original_env
  end

  it "creates a promotion-backed Stripe promotion code with the current API payload" do
    promotion = create(
      :promotion_code,
      :active,
      code: "LAUNCH15",
      percent_off: 15,
      stripe_coupon_id: nil,
      stripe_promotion_code_id: nil
    )
    coupon = instance_double(Stripe::Coupon, id: "coupon_launch15", percent_off: 15, duration: "once", metadata: {})
    stripe_promotion = instance_double(Stripe::PromotionCode, id: "promo_launch15", code: "LAUNCH15", active: true, metadata: {})

    expect(Stripe::Coupon).to receive(:create).with(
      hash_including(
        name: "LAUNCH15 15% off",
        percent_off: 15,
        duration: "once"
      )
    ).and_return(coupon)

    expect(Stripe::PromotionCode).to receive(:create) do |payload|
      expect(payload[:promotion]).to eq(type: "coupon", coupon: "coupon_launch15")
      expect(payload).to include(code: "LAUNCH15", active: true)
      expect(payload).not_to have_key(:coupon)

      stripe_promotion
    end

    described_class.new(promotion_code: promotion, replace_remote_objects: true).call

    expect(promotion.reload.stripe_coupon_id).to eq("coupon_launch15")
    expect(promotion.stripe_promotion_code_id).to eq("promo_launch15")
  end
end
