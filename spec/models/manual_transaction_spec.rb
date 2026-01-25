require "rails_helper"

RSpec.describe ManualTransaction, type: :model do
  it "is valid with one-time billing plan" do
    transaction = build(:manual_transaction)
    expect(transaction).to be_valid
  end

  it "rejects subscription billing plans" do
    transaction = build(:manual_transaction, billing_plan: create(:billing_plan))
    expect(transaction).not_to be_valid
  end

  it "enforces unique user and billing plan" do
    transaction = create(:manual_transaction)
    duplicate = build(:manual_transaction, user: transaction.user, billing_plan: transaction.billing_plan)

    expect(duplicate).not_to be_valid
  end

  it "blocks manual transactions when a Stripe charge already exists" do
    plan = create(:billing_plan, :one_time)
    user = create(:user)
    customer = user.pay_customers.create!(processor: "stripe", processor_id: "cus_charge_conflict", default: true)
    pay_charge = Pay::Charge.create!(customer: customer, processor_id: "ch_conflict", amount: 1200, currency: "usd")
    create(:marketplace_purchase, user: user, billing_plan: plan, pay_charge: pay_charge)

    transaction = build(:manual_transaction, user: user, billing_plan: plan)

    expect(transaction).not_to be_valid
    expect(transaction.errors[:base]).to include(I18n.t("errors.messages.billing_conflict"))
  end

  it "allowlists ransack associations and attributes" do
    expect(described_class.ransackable_associations).to match_array(%w[billing_plan recorded_by_admin user])
    expect(described_class.ransackable_attributes).to match_array(
      %w[billing_plan_id created_at id paid_at recorded_by_admin_id user_id]
    )
  end
end
