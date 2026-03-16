require "rails_helper"
require "securerandom"

RSpec.describe "Dashboard", type: :request do
  let(:user) { create(:user, :partner_enabled, preferred_locale: "es") }

  before do
    unless Pay::Subscription.method_defined?(:paused?)
      Pay::Subscription.define_method(:paused?) { false }
    end
  end

  def create_subscription_for(user, status: "active")
    customer = user.pay_customers.create!(
      processor: "stripe",
      processor_id: "cus_#{SecureRandom.hex(4)}",
      default: true
    )

    subscription = customer.subscriptions.create!(
      name: "default",
      processor_id: "sub_#{SecureRandom.hex(4)}",
      processor_plan: "price_123",
      status: status,
      quantity: 1,
      current_period_start: Time.current,
      current_period_end: 1.month.from_now
    )

    subscription.define_singleton_method(:paused?) { false }
    subscription
  end

  it "renders the dashboard with active subscription status" do
    create_subscription_for(user, status: "active")
    sign_in user, scope: :user

    get dashboard_path(locale: :es)

    expect(response).to be_successful
    expect(response.body).to include(I18n.t("dashboard.plan_card.status_active"))
  end

  it "shows inactive status when there is no active subscription" do
    sign_in user, scope: :user

    get dashboard_path

    expect(response).to be_successful
    expect(response.body).to include(I18n.t("dashboard.plan_card.status_inactive"))
  end

  it "shows a pending plan when a desired plan hint exists" do
    sign_in user, scope: :user

    get dashboard_path(locale: :en, price_key: "hft_monthly")

    expect(response).to be_successful
    expect(response.body).to include(I18n.t("dashboard.plan_card.status_pending", locale: :en))
  end

  it "renders chart sections when broker data exists" do
    ea = create(:expert_advisor, name: "Alpha")
    license = create(:license, user: user, expert_advisor: ea, status: "active", trial_ends_at: nil)
    account = create(:broker_account, license: license, company: "BrokerA", account_number: 1001)
    create(:broker_account_daily_result, broker_account: account, result_timestamp: Time.current.to_i, result_value: 150.0)

    sign_in user, scope: :user

    get dashboard_path(locale: :en)

    expect(response).to be_successful
    expect(response.body).to include("fintech-card-01")
    expect(response.body).to include("fintech-card-09")
    expect(response.body).to include(I18n.t("dashboard.main.account_summary.title", locale: :en))
  end

  it "renders empty states when no broker data exists" do
    sign_in user, scope: :user

    get dashboard_path(locale: :en)

    expect(response).to be_successful
    expect(response.body).to include(I18n.t("dashboard.main.pnl_card.empty", locale: :en))
    expect(response.body).to include(I18n.t("dashboard.main.balance_card.empty", locale: :en))
  end

  it "shows the active promotion modal on dashboard routes" do
    promotion = create(
      :promotion_code,
      :active,
      code: "MARCH25",
      percent_off: 25,
      title_en: "March special",
      body_en: "Use this promotion on your next Stripe checkout.",
      cta_label_en: "See plans"
    )
    sign_in user, scope: :user

    get dashboard_path(locale: :en)

    expect(response).to be_successful
    expect(response.body).to include("dashboard-discount-modal")
    expect(response.body).to include("March special")
    expect(response.body).to include(I18n.t("dashboard.discount_modal.code_label", locale: :en))
    expect(response.body).to include("MARCH25")

    get dashboard_plans_path(locale: :en)

    expect(response).to be_successful
    expect(response.body).to include("dashboard-discount-modal")
    expect(response.body).to include("promotion_code_id=#{promotion.id}")
  end

  it "renders long promotion content with the responsive modal hooks" do
    promotion = create(
      :promotion_code,
      :active,
      code: "LAUNCHINGGGGPROMOCODE2026SUPERLONG",
      percent_off: 15,
      title_en: "TESTING TESTINGTESTINGTESTING HERE WE GOOO",
      body_en: "LONG BODYYYYYYYYY BODYYYYYYYYYBODYYYYYYYYYBODYYYYYYYYYBODY",
      cta_label_en: "Get the limited offer nooooooooooooooooooooooooooooooooow"
    )
    sign_in user, scope: :user

    get dashboard_path(locale: :en)

    expect(response).to be_successful
    expect(response.body).to include(promotion.code)
    expect(response.body).to include("data-promotion-code-fit=\"true\"")
    expect(response.body).to include("promotion-modal-actions")
    expect(response.body).to include("promotion-modal-frame")
  end

  it "does not show a discount modal when no active promotion exists" do
    create(:promotion_code)
    sign_in user, scope: :user

    get dashboard_path(locale: :en)

    expect(response).to be_successful
    expect(response.body).not_to include("dashboard-discount-modal")
  end
end
