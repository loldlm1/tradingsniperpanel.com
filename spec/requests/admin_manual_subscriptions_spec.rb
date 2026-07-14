require "rails_helper"

RSpec.describe "Admin manual subscriptions", type: :request do
  let(:master_admin) { create(:user, :master_admin) }
  let(:customer) { create(:user) }
  let(:pandora_ea) { ExpertAdvisor.find_by(ea_id: "pandora_box") || create(:expert_advisor, ea_id: "pandora_box") }
  let(:plan) do
    billing_plan = BillingPlan.find_by(key: Billing::PandoraPricing::MONTHLY_KEY) || create(
      :billing_plan,
      tier: Billing::PandoraPricing::TIER,
      key: Billing::PandoraPricing::MONTHLY_KEY,
      interval: "month",
      interval_count: 1,
      amount_cents: Billing::PandoraPricing::MONTHLY_CENTS
    )
    BillingPlanEntitlement.find_or_create_by!(billing_plan: billing_plan, expert_advisor: pandora_ea)
    billing_plan
  end

  before do
    sign_in master_admin, scope: :user
  end

  it "creates access from an exact email, plan, and days" do
    revoked_license = create(
      :license,
      user: customer,
      expert_advisor: pandora_ea,
      status: "revoked",
      access_source: "one_time",
      trial_ends_at: nil,
      expires_at: 1.day.ago,
      source: Licenses::RevokeRoleAccess::ROLE_LICENSE_SOURCE
    )

    expect do
      post admin_manual_subscriptions_path, params: {
        manual_subscription: {
          request_id: SecureRandom.uuid,
          user_lookup: customer.email.upcase,
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

    revoked_license.reload
    expect(revoked_license).to be_active
    expect(revoked_license.source).to eq("manual_subscription")
    expect(revoked_license.expires_at).to eq(grant.ends_at)

    entry = Licenses::AccessibleExpertAdvisors.new(user: customer).call.find do |candidate|
      candidate.expert_advisor == pandora_ea
    end
    expect(entry.accessible).to be(true)
    expect(entry.license_key).to eq(revoked_license.encrypted_key)
  end

  it "searches users by case-insensitive email prefix with bounded email and name results" do
    match = create(:user, email: "lookup.00alice@example.com", name: "Alice Trader")
    create_list(:user, 22).each_with_index do |user, index|
      user.update!(email: format("lookup.%02d@example.com", index + 10))
    end

    get user_search_admin_manual_subscriptions_path, params: { q: "LOOKUP." }, as: :json

    expect(response).to have_http_status(:ok)
    results = response.parsed_body
    expect(results.length).to eq(20)
    expect(results).to include(
      "id" => match.id,
      "label" => "lookup.00alice@example.com - Alice Trader",
      "value" => "lookup.00alice@example.com"
    )
  end

  it "does not search until two email characters are provided" do
    get user_search_admin_manual_subscriptions_path, params: { q: "a" }, as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to eq([])
  end

  it "keeps email lookup behind the admin boundary" do
    sign_out master_admin
    sign_in customer, scope: :user

    get user_search_admin_manual_subscriptions_path, params: { q: "cu" }, as: :json

    expect(response).to redirect_to(root_path)
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

  it "revokes active manual access and records the operator" do
    subscription = create(:manual_subscription, user: customer, billing_plan: plan)
    request_id = SecureRandom.uuid

    expect do
      post revoke_admin_manual_subscription_path(subscription), params: { request_id: request_id }
    end.to change { subscription.reload.status }.from("active").to("cancelled")

    expect(response).to redirect_to(admin_manual_subscription_path(subscription))
    event = AdminAuditEvent.find_by!(request_id: request_id)
    expect(event.actor).to eq(master_admin)
    expect(event.target).to eq(customer)
    expect(event.metadata["manual_subscription_id"]).to eq(subscription.id)
  end

  it "does not revoke an expired manual subscription" do
    subscription = create(
      :manual_subscription,
      user: customer,
      billing_plan: plan,
      starts_at: 31.days.ago,
      ends_at: 1.day.ago,
      status: "expired"
    )

    expect do
      post revoke_admin_manual_subscription_path(subscription), params: { request_id: SecureRandom.uuid }
    end.not_to change(AdminAuditEvent, :count)

    expect(response).to redirect_to(admin_manual_subscription_path(subscription))
    expect(subscription.reload).to be_expired
  end
end
