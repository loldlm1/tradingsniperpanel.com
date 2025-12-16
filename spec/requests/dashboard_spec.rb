require "rails_helper"
require "securerandom"

RSpec.describe "Dashboard", type: :request do
  let(:user) { create(:user, preferred_locale: "es") }

  def create_subscription_for(user, status: "active")
    customer = user.pay_customers.create!(
      processor: "stripe",
      processor_id: "cus_#{SecureRandom.hex(4)}",
      default: true
    )

    customer.subscriptions.create!(
      name: "default",
      processor_id: "sub_#{SecureRandom.hex(4)}",
      processor_plan: "price_123",
      status: status,
      quantity: 1,
      current_period_start: Time.current,
      current_period_end: 1.month.from_now
    )
  end

  it "renders the dashboard with active subscription status" do
    create_subscription_for(user, status: "active")
    sign_in user

    get dashboard_path(locale: :es)

    expect(response).to be_successful
    expect(response.body).to include(I18n.t("dashboard.plan_card.status_active"))
  end

  it "shows inactive status when there is no active subscription" do
    sign_in user

    get dashboard_path

    expect(response).to be_successful
    expect(response.body).to include(I18n.t("dashboard.plan_card.status_inactive"))
  end

  it "renders the referral share URL with the locale" do
    sign_in user

    get dashboard_path(locale: :es)

    share_url = root_url(locale: :es, ref: user.referral_codes.first.code)
    expect(response.body).to include(share_url)
  end
end
