require "rails_helper"
require "securerandom"

RSpec.describe "Dashboard", type: :request do
  let(:user) { create(:user, :partner, preferred_locale: "es") }

  around do |example|
    original_discount_code = ENV["DISCOUNT_BANNER_CODE"]
    original_discount_percent = ENV["DISCOUNT_BANNER_PERCENT"]
    ENV.delete("DISCOUNT_BANNER_CODE")
    ENV.delete("DISCOUNT_BANNER_PERCENT")

    example.run
  ensure
    ENV["DISCOUNT_BANNER_CODE"] = original_discount_code
    ENV["DISCOUNT_BANNER_PERCENT"] = original_discount_percent
  end

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

  it "shows a discount modal on dashboard when discount env values are valid" do
    ENV["DISCOUNT_BANNER_CODE"] = "1234"
    ENV["DISCOUNT_BANNER_PERCENT"] = "15%"
    sign_in user, scope: :user

    get dashboard_path(locale: :en)

    expect(response).to be_successful
    expect(response.body).to include("dashboard-discount-modal")
    expect(response.body).to include(I18n.t("dashboard.discount_modal.title", percent: 15, locale: :en))
    expect(response.body).to include(I18n.t("dashboard.discount_modal.code_label", locale: :en))
    expect(response.body).to include("1234")
  end

  it "does not show a discount modal on dashboard when percent is invalid" do
    ENV["DISCOUNT_BANNER_CODE"] = "1234"
    ENV["DISCOUNT_BANNER_PERCENT"] = "fifteen"
    sign_in user, scope: :user

    get dashboard_path(locale: :en)

    expect(response).to be_successful
    expect(response.body).not_to include("dashboard-discount-modal")
  end
end
