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
end
