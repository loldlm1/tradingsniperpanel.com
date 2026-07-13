require "rails_helper"

RSpec.describe "Marketplace", type: :request do
  let(:user) { create(:user) }
  let(:marketplace_product) { create(:marketplace_product, title_en: "Legacy Bundle") }

  it "redirects unauthenticated users to sign in" do
    get dashboard_marketplace_path(locale: :en)

    expect(response).to have_http_status(:found)
    expect(response.headers["Location"]).to include(new_user_session_path(locale: :en))
  end

  it "keeps the customer marketplace unavailable even when legacy products remain active" do
    marketplace_product
    sign_in user, scope: :user

    get dashboard_marketplace_path(locale: :en)

    expect(response).to redirect_to(dashboard_plans_path(locale: :en))
    expect(flash[:alert]).to eq(I18n.t("dashboard.marketplace.unavailable", locale: :en))
  end

  it "rejects direct legacy product detail URLs" do
    sign_in user, scope: :user

    get dashboard_marketplace_product_path(marketplace_product, locale: :en)

    expect(response).to redirect_to(dashboard_plans_path(locale: :en))
    expect(flash[:alert]).to eq(I18n.t("dashboard.marketplace.unavailable", locale: :en))
  end

  it "rejects direct legacy marketplace checkout without creating a Stripe session" do
    checkout_stub = instance_double(Pay::Stripe::Customer)
    allow_any_instance_of(User).to receive(:payment_processor).and_return(checkout_stub)
    expect(checkout_stub).not_to receive(:checkout)
    sign_in user, scope: :user

    post dashboard_marketplace_product_checkout_path(marketplace_product, locale: :en),
         params: { refund_acknowledged: "1" }

    expect(response).to redirect_to(dashboard_plans_path(locale: :en))
  end

  it "does not render marketplace navigation for signed-in users" do
    marketplace_product
    sign_in user, scope: :user

    get dashboard_path(locale: :en)

    expect(response).to be_successful
    expect(response.body).not_to include("href=\"/dashboard/marketplace\"")
  end
end
