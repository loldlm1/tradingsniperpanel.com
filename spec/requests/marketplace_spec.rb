require "rails_helper"

RSpec.describe "Marketplace", type: :request do
  let(:user) { create(:user) }
  let(:marketplace_product) { create(:marketplace_product, title_en: "Pro Bundle") }
  let(:course) { create(:course, title_en: "Market Course") }

  it "redirects unauthenticated users to sign in" do
    get dashboard_marketplace_path(locale: :en)

    expect(response).to have_http_status(:found)
    expect(response.headers["Location"]).to include(new_user_session_path(locale: :en))
  end

  it "renders the marketplace index for signed-in users" do
    plan = create(:billing_plan, :one_time, key: "marketplace_course_index")
    create(:marketplace_product, billing_plan: plan, title_en: "Course Index Bundle")
    create(:course_plan_entitlement, course: course, billing_plan: plan)
    sign_in user, scope: :user

    get dashboard_marketplace_path(locale: :en)

    expect(response).to be_successful
    expect(response.body).to include("Course Index Bundle")
  end

  it "renders localized headings and sections when data is available" do
    course_plan = create(:billing_plan, :one_time, key: "marketplace_course_locale")
    course_product = create(:marketplace_product, billing_plan: course_plan, title_en: "Curso Alpha", title_es: "Curso Alpha")
    create(:course_plan_entitlement, course: create(:course, title_en: "Curso Alpha"), billing_plan: course_plan)

    ea_plan = create(:billing_plan, :one_time, key: "marketplace_ea_locale")
    ea_product = create(:marketplace_product, billing_plan: ea_plan, title_en: "EA Alpha", title_es: "EA Alpha")
    create(:billing_plan_entitlement, expert_advisor: create(:expert_advisor, name: "EA Alpha"), billing_plan: ea_plan)
    sign_in user, scope: :user

    get dashboard_marketplace_path(locale: :es)

    expect(response).to be_successful
    expect(response.body).to include(I18n.t("dashboard.marketplace.index.heading", locale: :es))
    expect(response.body).to include(I18n.t("dashboard.marketplace.sections.courses", locale: :es))
    expect(response.body).to include(I18n.t("dashboard.marketplace.sections.digital_goods", locale: :es))
    expect(response.body).to include(course_product.title_for(:es))
    expect(response.body).to include(ea_product.title_for(:es))
  end

  it "shows the empty state when no products exist" do
    sign_in user, scope: :user

    get dashboard_marketplace_path(locale: :en)

    expect(response).to be_successful
    expect(response.body).to include(I18n.t("dashboard.marketplace.index.empty_title", locale: :en))
    expect(response.body).not_to include(I18n.t("dashboard.marketplace.sections.courses", locale: :en))
    expect(response.body).not_to include("<!-- Cards 2 (Digital Goods) -->")
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

  it "blocks asset add-on purchases without base access" do
    asset = create(:marketplace_asset, title_en: "Rulebook", title_es: "Reglamento")
    base_plan = create(:billing_plan, :one_time)
    create(:asset_plan_entitlement, marketplace_asset: asset, billing_plan: base_plan)
    create(:marketplace_product, billing_plan: base_plan, title_en: "Rulebook")

    addon_plan = create(:billing_plan, :one_time)
    asset_addon = create(:addon, addonable: asset, billing_plan: addon_plan)
    create(:marketplace_product, billing_plan: addon_plan, title_en: "Rulebook Bonus")

    user.pay_customers.create!(processor: "stripe", processor_id: "cus_asset_addon_guard", default: true)
    sign_in user, scope: :user

    post dashboard_checkout_path(locale: :en, price_key: asset_addon.billing_plan.key)

    expect(response).to have_http_status(:found)
    expect(response.headers["Location"]).to include("/dashboard/marketplace")
    expect(flash[:alert]).to eq(
      I18n.t("dashboard.marketplace.errors.addon_requires_base", base: asset.title_for(:en))
    )
  end
end
