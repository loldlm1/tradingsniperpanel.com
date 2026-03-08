require "rails_helper"

RSpec.describe Billing::ApplyDashboardPromotion do
  let(:user) { create(:user) }
  let(:checkout_params) do
    {
      mode: "subscription",
      line_items: [{ price: "price_123", quantity: 1 }],
      allow_promotion_codes: true
    }
  end

  it "applies the selected active dashboard promotion code" do
    promotion = create(:promotion_code, :active, stripe_promotion_code_id: "promo_dashboard")

    result = described_class.new(
      user: user,
      checkout_params: checkout_params,
      promotion_code_id: promotion.id
    ).call

    expect(result[:discounts]).to eq([{ promotion_code: "promo_dashboard" }])
    expect(result).not_to have_key(:allow_promotion_codes)
    expect(result[:subscription_data][:metadata]["dashboard_promotion_code"]).to eq(promotion.code)
  end

  it "returns the original checkout params when another discount already exists" do
    promotion = create(:promotion_code, :active, stripe_promotion_code_id: "promo_dashboard")
    discounted = checkout_params.merge(discounts: [{ coupon: "coupon_referral" }]).tap { |params| params.delete(:allow_promotion_codes) }

    result = described_class.new(
      user: user,
      checkout_params: discounted,
      promotion_code_id: promotion.id
    ).call

    expect(result).to eq(discounted)
  end
end
