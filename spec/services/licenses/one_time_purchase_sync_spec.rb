require "rails_helper"
require "securerandom"

RSpec.describe Licenses::OneTimePurchaseSync do
  let(:user) { create(:user) }
  let(:customer) do
    user.pay_customers.create!(
      processor: "stripe",
      processor_id: "cus_#{SecureRandom.hex(4)}",
      default: true
    )
  end
  let!(:plan) { create(:billing_plan, :one_time, key: "one_time_basic", stripe_price_id: "price_one_time") }
  let!(:expert_advisor) { create(:expert_advisor, ea_id: "ea-basic") }
  let!(:entitlement) { create(:billing_plan_entitlement, billing_plan: plan, expert_advisor: expert_advisor) }
  let!(:charge) do
    Pay::Charge.create!(
      customer: customer,
      processor_id: "ch_#{SecureRandom.hex(4)}",
      amount: 1000,
      currency: "usd",
      metadata: { billing_plan_key: plan.key }
    )
  end

  it "creates active licenses for one-time entitlements" do
    encoder = instance_double(Licenses::LicenseKeyEncoder, generate: "ENCODED")

    described_class.new(pay_charge_id: charge.id, encoder: encoder).call

    license = License.find_by(user: user, expert_advisor: expert_advisor)
    expect(license).to be_active
    expect(license.source).to eq("stripe_charge")
    expect(license.encrypted_key).to eq("ENCODED")
  end
end
