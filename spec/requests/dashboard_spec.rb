require "rails_helper"
require "securerandom"

RSpec.describe "Dashboard", type: :request do
  let(:user) { create(:user, :partner, preferred_locale: "es") }

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

    plan_label = I18n.t(
      "dashboard.plan_card.plan_label",
      locale: :en,
      tier: I18n.t("dashboard.pricing.tiers.hft.name", locale: :en),
      interval: I18n.t("dashboard.pricing.toggle.monthly", locale: :en)
    )
    pending_copy = I18n.t("dashboard.plan_card.processing_with_plan", locale: :en, plan: plan_label)

    expect(response).to be_successful
    expect(response.body).to include(I18n.t("dashboard.plan_card.status_pending", locale: :en))
    expect(response.body).to include(pending_copy)
  end

  it "renders recent charge activity without errors" do
    customer = user.pay_customers.create!(
      processor: "stripe",
      processor_id: "cus_#{SecureRandom.hex(4)}",
      default: true
    )

    Pay::Charge.create!(
      customer: customer,
      processor_id: "ch_#{SecureRandom.hex(4)}",
      amount: 1500,
      currency: "usd",
      data: { "status" => "succeeded" }
    )

    sign_in user, scope: :user

    get dashboard_path(locale: :en)

    amount = ActionController::Base.helpers.number_to_currency(15.0, unit: "$", precision: 2)
    subtitle = I18n.t(
      "dashboard.activity.charge_subtitle",
      locale: :en,
      amount: amount,
      status: I18n.t("dashboard.activity.charge_status.succeeded", locale: :en)
    )

    expect(response).to be_successful
    expect(response.body).to include(subtitle)
  end

  it "renders the referral share URL with the locale" do
    sign_in user, scope: :user

    get dashboard_path(locale: :es)

    share_url = root_url(locale: :es, ref: user.referral_codes.first.code)
    expect(response.body).to include(share_url)
  end
end
