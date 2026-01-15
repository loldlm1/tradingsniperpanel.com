require "rails_helper"

RSpec.describe "Marketplace", type: :request do
  let(:user) { create(:user) }
  let(:marketplace_product) { create(:marketplace_product, title_en: "Pro Bundle") }

  it "redirects unauthenticated users to sign in" do
    get dashboard_marketplace_path(locale: :en)

    expect(response).to have_http_status(:found)
    expect(response.headers["Location"]).to include(new_user_session_path(locale: :en))
  end

  it "renders the marketplace index for signed-in users" do
    marketplace_product
    sign_in user, scope: :user

    get dashboard_marketplace_path(locale: :en)

    expect(response).to be_successful
    expect(response.body).to include("Pro Bundle")
  end

  it "renders the marketplace product detail page" do
    sign_in user, scope: :user

    get dashboard_marketplace_product_path(marketplace_product, locale: :en)

    expect(response).to be_successful
    expect(response.body).to include("Pro Bundle")
  end

  it "blocks repurchase attempts for the same marketplace plan" do
    create(:marketplace_purchase, user: user, billing_plan: marketplace_product.billing_plan)
    sign_in user, scope: :user

    post dashboard_checkout_path(locale: :en, price_key: marketplace_product.billing_plan.key)

    expect(response).to have_http_status(:found)
    expect(response.headers["Location"]).to include("/dashboard/marketplace")
    expect(flash[:alert]).to eq(I18n.t("dashboard.marketplace.errors.already_purchased"))
  end

  it "blocks add-on purchases without base access" do
    expert_advisor = create(:expert_advisor, name: "Addon Base EA")
    addon = create(:addon, addonable: expert_advisor)
    create(:marketplace_product, billing_plan: addon.billing_plan, title_en: "Addon Pack")
    user.pay_customers.create!(processor: "stripe", processor_id: "cus_addon_guard", default: true)
    sign_in user, scope: :user

    post dashboard_checkout_path(locale: :en, price_key: addon.billing_plan.key)

    expect(response).to have_http_status(:found)
    expect(response.headers["Location"]).to include("/dashboard/marketplace")
    expect(flash[:alert]).to eq(
      I18n.t("dashboard.marketplace.errors.addon_requires_base", base: expert_advisor.name)
    )
  end
end
