require "rails_helper"
require "securerandom"

RSpec.describe "Dashboard billing", type: :request do
  let(:user) { create(:user) }

  it "renders invoices using persisted Pay charges without status errors" do
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

    get dashboard_billing_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Invoices")
    expect(response.body).to include("$15")
    expect(response.body).to include("succeeded")
  end

  it "cancels a subscription from billing" do
    customer = user.pay_customers.create!(
      processor: "stripe",
      processor_id: "cus_#{SecureRandom.hex(4)}",
      default: true
    )

    subscription = customer.subscriptions.create!(
      name: "default",
      processor_id: "sub_#{SecureRandom.hex(4)}",
      processor_plan: "price_basic_monthly",
      status: "active",
      quantity: 1,
      current_period_start: Time.current,
      current_period_end: 1.month.from_now,
      type: "Pay::Stripe::Subscription"
    )

    schedule_result = Billing::CancelScheduledPlanChange::Result.new(status: :no_schedule)
    schedule_double = instance_double(Billing::CancelScheduledPlanChange, call: schedule_result)
    allow(Billing::CancelScheduledPlanChange).to receive(:new).and_return(schedule_double)

    allow_any_instance_of(Pay::Stripe::Subscription).to receive(:cancel) do |record|
      record.update!(ends_at: 1.month.from_now)
      true
    end
    allow_any_instance_of(Pay::Stripe::Subscription).to receive(:sync!).and_return(true)

    sign_in user, scope: :user

    post dashboard_cancel_subscription_path

    subscription.reload
    expect(response).to redirect_to(dashboard_billing_path)
    expect(flash[:notice]).to eq(I18n.t("dashboard.billing.cancel_success", date: I18n.l(subscription.ends_at.to_date)))
  end
end
