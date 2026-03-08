require "rails_helper"

RSpec.describe "Promotion codes admin", type: :request do
  around do |example|
    original_env = ENV["STRIPE_PRIVATE_KEY"]
    ENV["STRIPE_PRIVATE_KEY"] = "sk_test_123"
    example.run
  ensure
    ENV["STRIPE_PRIVATE_KEY"] = original_env
  end

  def promotion_params(overrides = {})
    {
      code: "MARCH25",
      percent_off: "25",
      active: "1",
      title_en: "March special",
      title_es: "Especial de marzo",
      body_en: "Fresh offer for your next Stripe checkout.",
      body_es: "Nueva oferta para tu próximo checkout de Stripe.",
      cta_label_en: "See plans",
      cta_label_es: "Ver planes",
      expires_at: "",
      max_redemptions: ""
    }.merge(overrides)
  end

  it "allows admins to create promotion codes" do
    admin = create(:user, :admin)
    sign_in admin, scope: :user
    stub_stripe_coupon_and_promotion_code(coupon_id: "coupon_admin", promotion_code_id: "promo_admin", code: "MARCH25", percent_off: 25)

    expect {
      post admin_promotion_codes_path, params: { promotion_code: promotion_params }
    }.to change(PromotionCode, :count).by(1)

    promotion = PromotionCode.last
    expect(response).to redirect_to(admin_promotion_code_path(promotion))
    expect(promotion.code).to eq("MARCH25")
    expect(promotion).to be_active
  end

  it "activates a promotion and deactivates the previous active one" do
    admin = create(:user, :admin)
    active_promotion = create(:promotion_code, :active, code: "SPRING15")
    inactive_promotion = create(:promotion_code, code: "MARCH25")
    sign_in admin, scope: :user
    stub_stripe_coupon_and_promotion_code

    post activate_admin_promotion_code_path(inactive_promotion)

    expect(response).to redirect_to(admin_promotion_code_path(inactive_promotion))
    expect(inactive_promotion.reload).to be_active
    expect(active_promotion.reload).not_to be_active
  end

  it "archives and restores a promotion" do
    admin = create(:user, :admin)
    promotion = create(:promotion_code)
    sign_in admin, scope: :user
    stub_stripe_coupon_and_promotion_code

    post archive_admin_promotion_code_path(promotion)
    expect(response).to redirect_to(admin_promotion_code_path(promotion))
    expect(promotion.reload.archived_at).to be_present

    post restore_admin_promotion_code_path(promotion)
    expect(response).to redirect_to(admin_promotion_code_path(promotion))
    expect(promotion.reload.archived_at).to be_nil
  end
end
