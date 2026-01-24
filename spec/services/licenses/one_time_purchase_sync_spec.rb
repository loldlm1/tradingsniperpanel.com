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
  let!(:marketplace_product) { create(:marketplace_product) }
  let!(:plan) { marketplace_product.billing_plan }
  let!(:extra_plan) { create(:billing_plan, :one_time) }
  let!(:extra_product) { create(:marketplace_product, billing_plan: extra_plan) }
  let!(:expert_advisor) { create(:expert_advisor, ea_id: "ea-basic") }
  let!(:course) { create(:course, slug: "course-basic") }
  let!(:entitlement) { create(:billing_plan_entitlement, billing_plan: plan, expert_advisor: expert_advisor) }
  let!(:course_entitlement) { create(:course_plan_entitlement, billing_plan: plan, course: course) }
  let!(:charge) do
    Pay::Charge.create!(
      customer: customer,
      processor_id: "ch_#{SecureRandom.hex(4)}",
      amount: 1000,
      currency: "usd",
      metadata: { billing_plan_keys: "#{plan.key},#{extra_plan.key}" }
    )
  end

  it "creates licenses, enrollments, and marketplace purchases for one-time entitlements" do
    encoder = instance_double(Licenses::LicenseKeyEncoder, generate: "ENCODED")

    described_class.new(pay_charge_id: charge.id, encoder: encoder).call

    license = License.find_by(user: user, expert_advisor: expert_advisor)
    expect(license).to be_active
    expect(license.access_source).to eq("one_time")
    expect(license.source).to eq("stripe_charge")
    expect(license.encrypted_key).to eq("ENCODED")

    enrollment = CourseEnrollment.find_by(user: user, course: course)
    expect(enrollment).to be_present
    expect(enrollment.access_source).to eq("one_time")
    expect(enrollment.pay_charge_id).to eq(charge.id)

    purchase = MarketplacePurchase.find_by(user: user, billing_plan: plan)
    expect(purchase).to be_present

    extra_purchase = MarketplacePurchase.find_by(user: user, billing_plan: extra_plan)
    expect(extra_purchase).to be_present
  end
end
