require "rails_helper"

RSpec.describe Admin::SubscriptionAudits::InvoiceSnapshot do
  it "normalizes failed invoice evidence without exposing the raw event" do
    webhook = Pay::Webhook.create!(
      processor: "stripe",
      event_type: "invoice.payment_failed",
      event: {
        "created" => 1_700_000_000,
        "data" => {
          "object" => {
            "id" => "in_failed",
            "customer" => "cus_failed",
            "subscription" => "sub_failed",
            "status" => "open",
            "amount_due" => 7900,
            "currency" => "usd"
          }
        }
      }
    )

    snapshot = described_class.from_webhook(webhook)

    expect(snapshot.state).to eq("failed")
    expect(snapshot.amount_cents).to eq(7900)
    expect(snapshot.processor_reference).to eq("in_failed")
    expect(described_class.customer_reference(webhook)).to eq("cus_failed")
  end

  it "distinguishes succeeded, unpaid, and pending invoice states" do
    succeeded = webhook_for(event_type: "invoice.payment_succeeded", status: "paid")
    unpaid = webhook_for(event_type: "invoice.marked_uncollectible", status: "uncollectible")
    pending = webhook_for(event_type: "invoice.finalized", status: "open")

    expect(described_class.from_webhook(succeeded).state).to eq("succeeded")
    expect(described_class.from_webhook(unpaid).state).to eq("unpaid")
    expect(described_class.from_webhook(pending).state).to eq("pending")
  end

  it "uses local charge status and the amount due for unsettled invoices" do
    customer = Pay::Customer.create!(
      owner: create(:user),
      processor: "stripe",
      processor_id: "cus_charge_states",
      default: true
    )
    failed_charge = Pay::Charge.create!(
      customer: customer,
      processor_id: "ch_failed",
      amount: 7900,
      currency: "usd",
      data: { "status" => "failed" }
    )
    failed_invoice = Pay::Webhook.create!(
      processor: "stripe",
      event_type: "invoice.payment_failed",
      event: {
        "data" => {
          "object" => {
            "id" => "in_failed_amount",
            "customer" => customer.processor_id,
            "status" => "open",
            "amount_paid" => 0,
            "amount_due" => 7900,
            "currency" => "usd"
          }
        }
      }
    )

    expect(described_class.from_charge(failed_charge).state).to eq("failed")
    expect(described_class.from_charge(failed_charge)).not_to be_settled
    expect(described_class.from_webhook(failed_invoice).amount_cents).to eq(7900)
  end

  def webhook_for(event_type:, status:)
    Pay::Webhook.create!(
      processor: "stripe",
      event_type: event_type,
      event: {
        "data" => {
          "object" => {
            "id" => "in_#{status}",
            "customer" => "cus_states",
            "status" => status,
            "amount_due" => 7900,
            "currency" => "usd"
          }
        }
      }
    )
  end
end
