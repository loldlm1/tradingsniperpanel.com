require "rails_helper"

RSpec.describe Admin::PromotionCodeUpsert do
  around do |example|
    original_env = ENV["STRIPE_PRIVATE_KEY"]
    ENV["STRIPE_PRIVATE_KEY"] = "sk_test_123"
    example.run
  ensure
    ENV["STRIPE_PRIVATE_KEY"] = original_env
  end

  it "creates a Stripe-backed promotion and deactivates the previous active one" do
    active_promotion = create(:promotion_code, :active, code: "SPRING15", stripe_promotion_code_id: "promo_existing")
    stub_stripe_coupon_and_promotion_code(coupon_id: "coupon_new", promotion_code_id: "promo_new", code: "MARCH25", percent_off: 25)

    result = described_class.new(
      attributes: {
        code: "march25",
        percent_off: "25",
        active: "1",
        title_en: "March special",
        title_es: "Especial de marzo",
        body_en: "Fresh offer",
        body_es: "Oferta nueva",
        cta_label_en: "See plans",
        cta_label_es: "Ver planes"
      }
    ).call

    expect(result).to be_ok
    expect(result.promotion_code.reload.code).to eq("MARCH25")
    expect(result.promotion_code).to be_active
    expect(result.promotion_code.stripe_coupon_id).to eq("coupon_new")
    expect(result.promotion_code.stripe_promotion_code_id).to eq("promo_new")
    expect(active_promotion.reload).not_to be_active
  end

  it "replaces remote Stripe objects when immutable fields change" do
    promotion = create(
      :promotion_code,
      code: "SPRING15",
      stripe_coupon_id: "coupon_old",
      stripe_promotion_code_id: "promo_old"
    )

    stub_stripe_coupon_and_promotion_code(coupon_id: "coupon_replaced", promotion_code_id: "promo_replaced", code: "SPRING15", percent_off: 30)
    expect(Stripe::PromotionCode).to receive(:update).with("promo_old", { active: false }).and_return(
      instance_double(Stripe::PromotionCode, id: "promo_old", code: "SPRING15", active: false, metadata: {})
    )

    result = described_class.new(
      promotion_code: promotion,
      attributes: {
        code: "SPRING15",
        percent_off: "30",
        active: "0",
        title_en: promotion.title_en,
        title_es: promotion.title_es,
        body_en: promotion.body_en,
        body_es: promotion.body_es,
        cta_label_en: promotion.cta_label_en,
        cta_label_es: promotion.cta_label_es
      }
    ).call

    expect(result).to be_ok
    expect(promotion.reload.percent_off).to eq(30)
    expect(promotion.stripe_coupon_id).to eq("coupon_replaced")
    expect(promotion.stripe_promotion_code_id).to eq("promo_replaced")
  end
end
