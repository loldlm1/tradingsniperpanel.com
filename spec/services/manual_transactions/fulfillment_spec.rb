require "rails_helper"

RSpec.describe ManualTransactions::Fulfillment, type: :service do
  it "grants entitlements for manual one-time purchases" do
    user = create(:user)
    plan = create(:billing_plan, :one_time)
    create(:marketplace_product, billing_plan: plan)
    expert_advisor = create(:expert_advisor)
    course = create(:course)
    create(:billing_plan_entitlement, billing_plan: plan, expert_advisor: expert_advisor)
    create(:course_plan_entitlement, billing_plan: plan, course: course)

    transaction = create(:manual_transaction, user: user, billing_plan: plan, paid_at: 1.hour.ago)

    described_class.new(manual_transaction_id: transaction.id).call

    purchase = MarketplacePurchase.find_by(user: user, billing_plan: plan)
    expect(purchase).to be_present
    expect(purchase.purchased_at.to_i).to eq(transaction.paid_at.to_i)

    license = License.find_by(user: user, expert_advisor: expert_advisor)
    expect(license).to be_present
    expect(license).to be_active
    expect(license.access_source).to eq("one_time")

    enrollment = CourseEnrollment.find_by(user: user, course: course)
    expect(enrollment).to be_present
    expect(enrollment.access_source).to eq("one_time")
    expect(enrollment.purchased_at.to_i).to eq(transaction.paid_at.to_i)
  end
end
