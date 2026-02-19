require "rails_helper"

RSpec.describe BillingNotificationsMailer, type: :mailer do
  let(:user) { create(:user) }

  it "uses support_email as the sender" do
    email = described_class.with(
      user: user,
      plan_name: "Basic Monthly",
      amount_cents: 1_000,
      currency: "usd",
      invoice_id: "in_test",
      invoice_url: nil
    ).subscription_started

    expect(email.from).to eq([Rails.configuration.x.branding.support_email])
  end
end
