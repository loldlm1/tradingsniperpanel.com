require "rails_helper"
require "securerandom"

RSpec.describe Billing::StripeInvoiceNotificationProcessor do
  include ActiveJob::TestHelper

  let(:user) { create(:user) }
  let(:pay_customer) do
    user.pay_customers.create!(
      processor: "stripe",
      processor_id: "cus_#{SecureRandom.hex(4)}",
      default: true
    )
  end
  let!(:plan) do
    create(
      :billing_plan,
      tier: "basic",
      key: "basic_monthly",
      interval: "month",
      interval_count: 1,
      stripe_price_id: "price_basic_monthly",
      amount_cents: 1_000
    )
  end
  let!(:subscription) do
    pay_customer.subscriptions.create!(
      name: "default",
      processor_id: "sub_#{SecureRandom.hex(4)}",
      processor_plan: plan.stripe_price_id,
      status: "active",
      quantity: 1,
      current_period_start: Time.current,
      current_period_end: 1.month.from_now,
      type: "Pay::Stripe::Subscription"
    )
  end

  before do
    clear_enqueued_jobs
  end

  after do
    clear_enqueued_jobs
  end

  it "enqueues subscription_started for immediate subscription creation charges" do
    event = build_event(type: "invoice.payment_succeeded")

    expect do
      described_class.new(event: event).call
    end.to have_enqueued_mail(BillingNotificationsMailer, :subscription_started)

    delivery = BillingEmailDelivery.find_by(event_key: "subscription_started:#{event.data.object.id}")
    expect(delivery).to be_present
    expect(delivery.event_type).to eq("subscription_started")
  end

  it "enqueues subscription_upgraded for immediate upgrade charges" do
    event = build_event(
      type: "invoice.payment_succeeded",
      invoice_overrides: { billing_reason: "subscription_update" }
    )

    expect do
      described_class.new(event: event).call
    end.to have_enqueued_mail(BillingNotificationsMailer, :subscription_upgraded)
  end

  it "sends one renewal-failed email per billing cycle invoice" do
    invoice_id = "in_renewal_#{SecureRandom.hex(4)}"
    event = build_event(
      type: "invoice.payment_failed",
      invoice_overrides: {
        id: invoice_id,
        billing_reason: "subscription_cycle",
        amount_paid: 0,
        amount_due: 2_000
      }
    )

    expect do
      described_class.new(event: event).call
    end.to have_enqueued_mail(BillingNotificationsMailer, :subscription_renewal_payment_failed)

    clear_enqueued_jobs

    expect do
      described_class.new(event: event).call
    end.not_to have_enqueued_mail(BillingNotificationsMailer, :subscription_renewal_payment_failed)

    expect(BillingEmailDelivery.where(event_key: "subscription_renewal_payment_failed:#{invoice_id}").count).to eq(1)
  end

  it "does not enqueue upgrade email when the invoice has no immediate charge" do
    event = build_event(
      type: "invoice.payment_succeeded",
      invoice_overrides: {
        billing_reason: "subscription_update",
        amount_paid: 0
      }
    )

    expect do
      described_class.new(event: event).call
    end.not_to have_enqueued_mail(BillingNotificationsMailer, :subscription_upgraded)
  end

  def build_event(type:, invoice_overrides: {})
    invoice = {
      "id" => "in_#{SecureRandom.hex(4)}",
      "customer" => pay_customer.processor_id,
      "subscription" => subscription.processor_id,
      "billing_reason" => "subscription_create",
      "currency" => "usd",
      "amount_paid" => 1_500,
      "amount_due" => 0,
      "hosted_invoice_url" => "https://stripe.example.com/invoice",
      "lines" => {
        "data" => [
          {
            "amount" => 1_500,
            "pricing" => {
              "price_details" => {
                "price" => plan.stripe_price_id
              }
            }
          }
        ]
      }
    }.merge(invoice_overrides.deep_stringify_keys)

    Stripe::Event.construct_from(
      {
        "id" => "evt_#{SecureRandom.hex(4)}",
        "type" => type,
        "data" => {
          "object" => invoice
        }
      }
    )
  end
end
