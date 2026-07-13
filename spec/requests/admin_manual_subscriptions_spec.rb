require "rails_helper"

RSpec.describe "Admin manual subscriptions", type: :request do
  let(:master_admin) { create(:user, :master_admin) }
  let(:customer) { create(:user) }
  let(:pandora_ea) { create(:expert_advisor, ea_id: "pandora_box") }
  let(:plan) do
    create(:billing_plan, tier: "pandora_pro", key: "pandora_pro_monthly", interval: "month", interval_count: 1).tap do |billing_plan|
      create(:billing_plan_entitlement, billing_plan: billing_plan, expert_advisor: pandora_ea)
    end
  end

  before do
    sign_in master_admin, scope: :user
  end

  it "creates access from the simple user, plan, and days form" do
    expect do
      post admin_manual_subscriptions_path, params: {
        manual_subscription: {
          request_id: SecureRandom.uuid,
          user_id: customer.id,
          billing_plan_id: plan.id,
          granted_days: 45,
          payment_status: "",
          amount_cents: "0"
        }
      }
    end.to change(ManualSubscription, :count).by(1)

    grant = ManualSubscription.order(:id).last
    expect(response).to redirect_to(admin_manual_subscription_path(grant))
    expect(grant.user).to eq(customer)
    expect(grant.billing_plan).to eq(plan)
    expect(grant.granted_days).to eq(45)
    expect(grant.recorded_by_admin).to eq(master_admin)
    expect(grant).to be_payment_complimentary
  end

  it "rejects non-Pandora plans" do
    other_plan = create(:billing_plan)

    expect do
      post admin_manual_subscriptions_path, params: {
        manual_subscription: {
          request_id: SecureRandom.uuid,
          user_id: customer.id,
          billing_plan_id: other_plan.id,
          granted_days: 30
        }
      }
    end.not_to change(ManualSubscription, :count)

    expect(response).to redirect_to(new_admin_manual_subscription_path)
  end

  it "records optional paid grant details" do
    paid_at = Time.current.change(usec: 0)

    post admin_manual_subscriptions_path, params: {
      manual_subscription: {
        request_id: SecureRandom.uuid,
        user_id: customer.id,
        billing_plan_id: plan.id,
        granted_days: 30,
        payment_status: "paid",
        amount_cents: "7900",
        paid_at: paid_at.iso8601,
        reference: "manual-invoice-1"
      }
    }

    grant = ManualSubscription.order(:id).last
    expect(response).to redirect_to(admin_manual_subscription_path(grant))
    expect(grant).to be_payment_paid
    expect(grant.amount_cents).to eq(7900)
    expect(grant.paid_at).to eq(paid_at)
    expect(grant.reference).to eq("manual-invoice-1")
  end
end
