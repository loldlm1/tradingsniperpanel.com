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

  it "shows one-time online seat copy for EA products on index and detail" do
    ea_plan = create(:billing_plan, :one_time, key: "marketplace_online_seat_copy")
    ea_product = create(:marketplace_product, billing_plan: ea_plan, title_en: "Seat EA Pack")
    create(:billing_plan_entitlement, expert_advisor: create(:expert_advisor, name: "Seat EA"), billing_plan: ea_plan)
    sign_in user, scope: :user

    get dashboard_marketplace_path(locale: :en, tab: "expert_advisors")

    expect(response).to be_successful
    expect(response.body).to include(I18n.t("licenses.online_seats.one_time_feature", count: 8, locale: :en))

    get dashboard_marketplace_product_path(ea_product, locale: :en)

    expect(response).to be_successful
    expect(response.body).to include(I18n.t("licenses.online_seats.one_time_feature", count: 8, locale: :en))
  end

  it "renders dynamic pagination controls when a section has more than eight cards" do
    9.times do |index|
      expert_advisor = create(:expert_advisor, name: "Pagination EA #{index}")
      plan = create(:billing_plan, :one_time, key: "marketplace_pagination_ea_#{index}")
      create(:marketplace_product, billing_plan: plan, title_en: "Pagination Bundle #{index}")
      create(:billing_plan_entitlement, expert_advisor: expert_advisor, billing_plan: plan)
    end
    sign_in user, scope: :user

    get dashboard_marketplace_path(locale: :en, tab: "expert_advisors")

    expect(response).to be_successful
    expect(response.body).to include("data-pagination-container")
    expect(response.body).to include("data-page-size=\"8\"")
    expect(response.body).to include("data-pagination-page=\"2\"")
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

  it "renders marketplace overview markdown as HTML" do
    markdown_plan = create(:billing_plan, :one_time, key: "marketplace_markdown_overview")
    markdown_product = create(
      :marketplace_product,
      billing_plan: markdown_plan,
      title_en: "Markdown Product",
      description_en: "# Overview\n\n## Detailed behavior\n\n- First item\n- Second item"
    )
    sign_in user, scope: :user

    get dashboard_marketplace_product_path(markdown_product, locale: :en)

    expect(response).to be_successful
    expect(response.body).to include("id=\"overview\"")
    expect(response.body).to include("id=\"detailed-behavior\"")
    expect(response.body).to include("<li class=\"leading-relaxed\">First item</li>")
    expect(response.body).not_to include("# Overview")
    expect(response.body).not_to include("## Detailed behavior")
  end

  it "blocks repurchase attempts for the same marketplace plan" do
    create(:marketplace_purchase, user: user, billing_plan: marketplace_product.billing_plan)
    sign_in user, scope: :user

    post dashboard_checkout_path(locale: :en, price_key: marketplace_product.billing_plan.key)

    expect(response).to have_http_status(:found)
    expect(response.headers["Location"]).to include("/dashboard/marketplace")
    expect(flash[:alert]).to eq(I18n.t("dashboard.marketplace.errors.already_purchased"))
  end

  it "blocks checkout when a manual transaction already exists" do
    create(:manual_transaction, user: user, billing_plan: marketplace_product.billing_plan)
    sign_in user, scope: :user

    post dashboard_checkout_path(locale: :en, price_key: marketplace_product.billing_plan.key)

    expect(response).to have_http_status(:found)
    expect(response.headers["Location"]).to include("/dashboard/marketplace")
    expect(flash[:alert]).to eq(I18n.t("dashboard.marketplace.errors.already_purchased"))
  end

  it "blocks dashboard checkout for privileged users" do
    privileged_user = create(:user, :full_trader)
    sign_in privileged_user, scope: :user

    post dashboard_checkout_path(locale: :en, price_key: marketplace_product.billing_plan.key)

    expect(response).to redirect_to(dashboard_plans_path(locale: :en))
    expect(flash[:alert]).to eq(I18n.t("dashboard.billing.privileged_checkout_blocked", locale: :en))
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

  it "creates a checkout session for base and selected add-ons" do
    base_plan = create(:billing_plan, :one_time, key: "marketplace_base")
    base_product = create(:marketplace_product, billing_plan: base_plan, title_en: "Base Bundle")
    expert_advisor = create(:expert_advisor, name: "Bundle EA")
    create(:billing_plan_entitlement, billing_plan: base_plan, expert_advisor: expert_advisor)

    addon_plan = create(:billing_plan, :one_time, key: "marketplace_addon")
    create(:addon, addonable: expert_advisor, billing_plan: addon_plan)
    create(:marketplace_product, billing_plan: addon_plan, title_en: "Addon Pack")

    user.pay_customers.create!(processor: "stripe", processor_id: "cus_marketplace_checkout", default: true)
    sign_in user, scope: :user

    checkout_stub = instance_double(Pay::Stripe::Customer)
    allow_any_instance_of(User).to receive(:payment_processor).and_return(checkout_stub)

    expect(checkout_stub).to receive(:checkout) do |**params|
      expect(params[:mode]).to eq("payment")
      expect(params[:allow_promotion_codes]).to eq(true)
      expect(params[:line_items]).to contain_exactly(
        { price: base_plan.stripe_price_id, quantity: 1 },
        { price: addon_plan.stripe_price_id, quantity: 1 }
      )
      keys = params.dig(:payment_intent_data, :metadata, "billing_plan_keys").to_s.split(",")
      expect(keys).to match_array([base_plan.key, addon_plan.key])
      double(url: "https://checkout.test/session")
    end

    post dashboard_marketplace_product_checkout_path(base_product, locale: :en),
         params: { base_plan_key: base_plan.key, addon_keys: [addon_plan.key], refund_acknowledged: "1" }

    expect(response).to redirect_to("https://checkout.test/session")
  end

  it "does not apply referral discounts to marketplace checkout after redemption" do
    referrer = create(:user)
    referred_user = create(:user)
    create(:partner_profile, user: referrer, referral_code: "PARTNER30", discount_percent: 10)
    Referrals::AttachReferrer.new(user: referred_user, code: "PARTNER30").call
    Referrals::MarkCompleted.new(user: referred_user).call

    base_plan = create(:billing_plan, :one_time, key: "marketplace_referral_completed")
    base_product = create(:marketplace_product, billing_plan: base_plan, title_en: "Completed Referral Bundle")
    create(:billing_plan_entitlement, billing_plan: base_plan, expert_advisor: create(:expert_advisor, name: "Completed Referral EA"))

    referred_user.pay_customers.create!(processor: "stripe", processor_id: "cus_marketplace_referral_completed", default: true)
    sign_in referred_user, scope: :user

    checkout_stub = instance_double(Pay::Stripe::Customer)
    allow_any_instance_of(User).to receive(:payment_processor).and_return(checkout_stub)

    expect(checkout_stub).to receive(:checkout) do |**params|
      expect(params).not_to have_key(:discounts)
      expect(params[:allow_promotion_codes]).to eq(true)
      double(url: "https://checkout.test/marketplace-completed")
    end

    post dashboard_marketplace_product_checkout_path(base_product, locale: :en),
         params: { refund_acknowledged: "1" }

    expect(response).to redirect_to("https://checkout.test/marketplace-completed")
  end

  it "renders the promotion modal and loading-label markup on marketplace product pages" do
    create(:promotion_code, :active, code: "MARCH25", title_en: "March special", body_en: "Use the code at checkout.", cta_label_en: "See plans")
    sign_in user, scope: :user

    get dashboard_marketplace_product_path(marketplace_product, locale: :en)

    expect(response).to be_successful
    expect(response.body).to include("dashboard-discount-modal")
    expect(response.body).to include("MARCH25")
    expect(response.body).to include("data-loading-label")
    expect(response.body).to include("data-loading-spinner")
    expect(response.body).to include("data-loading-target=\"true\"")
    expect(response.body).to include("promotion-modal-copy-button")
  end

  it "blocks marketplace checkout when a manual base purchase exists" do
    base_plan = create(:billing_plan, :one_time, key: "manual_base")
    base_product = create(:marketplace_product, billing_plan: base_plan, title_en: "Manual Base")
    create(:manual_transaction, user: user, billing_plan: base_plan)

    user.pay_customers.create!(processor: "stripe", processor_id: "cus_manual_base", default: true)
    sign_in user, scope: :user

    post dashboard_marketplace_product_checkout_path(base_product, locale: :en),
         params: { refund_acknowledged: "1" }

    expect(response).to have_http_status(:found)
    expect(response.headers["Location"]).to include("/dashboard/marketplace/#{base_product.slug}")
    expect(flash[:alert]).to eq(I18n.t("dashboard.marketplace.errors.already_purchased"))
  end

  it "blocks marketplace product checkout for privileged users" do
    base_plan = create(:billing_plan, :one_time, key: "marketplace_privileged_base")
    base_product = create(:marketplace_product, billing_plan: base_plan, title_en: "Privileged Base")
    privileged_user = create(:user, :full_trader)
    sign_in privileged_user, scope: :user

    post dashboard_marketplace_product_checkout_path(base_product, locale: :en),
         params: { refund_acknowledged: "1" }

    expect(response).to redirect_to(dashboard_marketplace_product_path(base_product, locale: :en))
    expect(flash[:alert]).to eq(I18n.t("dashboard.marketplace.errors.privileged_checkout_blocked", locale: :en))
  end

  it "creates a checkout session with add-ons only when base is owned" do
    base_plan = create(:billing_plan, :one_time, key: "marketplace_base_owned")
    base_product = create(:marketplace_product, billing_plan: base_plan, title_en: "Owned Bundle")
    expert_advisor = create(:expert_advisor, name: "Owned EA")
    create(:billing_plan_entitlement, billing_plan: base_plan, expert_advisor: expert_advisor)

    addon_plan = create(:billing_plan, :one_time, key: "marketplace_addon_owned")
    create(:addon, addonable: expert_advisor, billing_plan: addon_plan)
    create(:marketplace_product, billing_plan: addon_plan, title_en: "Addon Pack")

    create(:marketplace_purchase, user: user, billing_plan: base_plan)
    create(:license, :one_time, user: user, expert_advisor: expert_advisor)
    user.pay_customers.create!(processor: "stripe", processor_id: "cus_marketplace_checkout_owned", default: true)
    sign_in user, scope: :user

    checkout_stub = instance_double(Pay::Stripe::Customer)
    allow_any_instance_of(User).to receive(:payment_processor).and_return(checkout_stub)

    expect(checkout_stub).to receive(:checkout) do |**params|
      expect(params[:line_items]).to contain_exactly(
        { price: addon_plan.stripe_price_id, quantity: 1 }
      )
      double(url: "https://checkout.test/session")
    end

    post dashboard_marketplace_product_checkout_path(base_product, locale: :en),
         params: { base_plan_key: base_plan.key, addon_keys: [addon_plan.key], refund_acknowledged: "1" }

    expect(response).to redirect_to("https://checkout.test/session")
  end

  it "shows the add-ons empty state and progress when no add-ons exist" do
    base_plan = create(:billing_plan, :one_time)
    base_product = create(:marketplace_product, billing_plan: base_plan, title_en: "Base Bundle")
    expert_advisor = create(:expert_advisor, name: "Base EA")
    create(:billing_plan_entitlement, billing_plan: base_plan, expert_advisor: expert_advisor)
    sign_in user, scope: :user

    get dashboard_marketplace_product_path(base_product, locale: :en)

    expect(response).to be_successful
    expect(response.body).to include(I18n.t("dashboard.marketplace.show.addons.title", locale: :en))
    expect(response.body).to include(I18n.t("dashboard.marketplace.show.addons.empty", locale: :en))
    expect(response.body).to include("0/0")
  end

  it "hides owned add-ons from the add-ons list" do
    base_plan = create(:billing_plan, :one_time)
    base_product = create(:marketplace_product, billing_plan: base_plan, title_en: "Base Bundle")
    expert_advisor = create(:expert_advisor, name: "Base EA")
    create(:billing_plan_entitlement, billing_plan: base_plan, expert_advisor: expert_advisor)

    addon_plan = create(:billing_plan, :one_time)
    create(:addon, addonable: expert_advisor, billing_plan: addon_plan)
    create(:marketplace_product, billing_plan: addon_plan, title_en: "Hidden Addon")
    create(:marketplace_purchase, user: user, billing_plan: addon_plan)

    sign_in user, scope: :user

    get dashboard_marketplace_product_path(base_product, locale: :en)

    expect(response).to be_successful
    expect(response.body).not_to include("data-addon-key=\"#{addon_plan.key}\"")
    expect(response.body).to include(I18n.t("dashboard.marketplace.show.addons.empty", locale: :en))
  end

  it "shows a base missing warning for add-on products without a base" do
    expert_advisor = create(:expert_advisor, name: "Addon EA")
    addon_plan = create(:billing_plan, :one_time)
    create(:addon, addonable: expert_advisor, billing_plan: addon_plan)
    addon_product = create(:marketplace_product, billing_plan: addon_plan, title_en: "Addon Only")
    sign_in user, scope: :user

    get dashboard_marketplace_product_path(addon_product, locale: :en)

    expect(response).to be_successful
    expect(response.body).to include(I18n.t("dashboard.marketplace.show.base_missing", locale: :en))
  end

  it "allows addon page checkout with paid subscription access when no base marketplace product exists" do
    expert_advisor = create(:expert_advisor, name: "Fibonacci Elite EA", allowed_subscription_tiers: %w[basic])
    addon_plan = create(:billing_plan, :one_time, key: "addon_fibonacci_compound_reversal_early")
    create(:addon, key: "addon_compound_reversal_early", addonable: expert_advisor, billing_plan: addon_plan)
    addon_product = create(:marketplace_product, billing_plan: addon_plan, title_en: "Compound Mode - Reversal Early")

    subscription_plan = create(:billing_plan, tier: "basic")
    create(:manual_subscription, user: user, billing_plan: subscription_plan, recorded_by_admin: create(:user, :admin))

    user.pay_customers.create!(processor: "stripe", processor_id: "cus_marketplace_addon_only", default: true)
    sign_in user, scope: :user

    get dashboard_marketplace_product_path(addon_product, locale: :en)

    expect(response).to be_successful
    expect(response.body).not_to include(I18n.t("dashboard.marketplace.show.base_missing", locale: :en))
    expect(response.body).to include("data-addon-key=\"#{addon_plan.key}\"")

    checkout_stub = instance_double(Pay::Stripe::Customer)
    allow_any_instance_of(User).to receive(:payment_processor).and_return(checkout_stub)
    expect(checkout_stub).to receive(:checkout) do |**params|
      expect(params[:line_items]).to eq([{ price: addon_plan.stripe_price_id, quantity: 1 }])
      double(url: "https://checkout.test/session")
    end

    post dashboard_marketplace_product_checkout_path(addon_product, locale: :en),
         params: { refund_acknowledged: "1", addon_keys: [addon_plan.key] }

    expect(response).to redirect_to("https://checkout.test/session")
  end

  it "redirects with an error when no items are selected for checkout" do
    base_plan = create(:billing_plan, :one_time)
    base_product = create(:marketplace_product, billing_plan: base_plan, title_en: "Owned Base")
    expert_advisor = create(:expert_advisor, name: "Owned EA")
    create(:billing_plan_entitlement, billing_plan: base_plan, expert_advisor: expert_advisor)
    create(:marketplace_purchase, user: user, billing_plan: base_plan)
    create(:license, :one_time, user: user, expert_advisor: expert_advisor)
    sign_in user, scope: :user

    post dashboard_marketplace_product_checkout_path(base_product, locale: :en),
         params: { base_plan_key: base_plan.key, addon_keys: [], refund_acknowledged: "1" }

    expect(response).to redirect_to(dashboard_marketplace_product_path(base_product, locale: :en))
    expect(flash[:alert]).to eq(I18n.t("dashboard.marketplace.errors.no_items_selected", locale: :en))
  end
end
