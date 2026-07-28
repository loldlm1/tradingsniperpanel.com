require "rails_helper"

RSpec.describe "Admin subscription audits", type: :request do
  let(:pandora_ea) { create(:expert_advisor, ea_id: "pandora_box") }
  let(:plan) do
    monthly = create(
      :billing_plan,
      tier: "pandora_pro",
      key: "pandora_pro_monthly",
      interval: "month",
      interval_count: 1,
      amount_cents: 7900
    ).tap { |billing_plan| create(:billing_plan_entitlement, billing_plan: billing_plan, expert_advisor: pandora_ea) }
    create(
      :billing_plan,
      tier: "pandora_pro",
      key: "pandora_pro_annual",
      interval: "year",
      interval_count: 1,
      amount_cents: Billing::PandoraPricing::ANNUAL_CENTS
    ).tap { |billing_plan| create(:billing_plan_entitlement, billing_plan: billing_plan, expert_advisor: pandora_ea) }
    monthly
  end

  it "renders a local-only audit index and detail without license secrets" do
    admin = create(:user, :admin)
    user, _subscription = create_subscribed_user
    license = create(
      :license,
      user: user,
      expert_advisor: pandora_ea,
      status: "active",
      trial_ends_at: nil,
      expires_at: 1.month.from_now
    )
    chu_ea = create(:expert_advisor, ea_id: "chu_sniper_trailing", name: "Chu Sniper Trailing")
    chu_license = create(
      :license,
      user: user,
      expert_advisor: chu_ea,
      status: "active",
      trial_ends_at: nil,
      expires_at: 1.month.from_now
    )
    sign_in admin, scope: :user

    get admin_subscription_audits_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(user.email)
    expect(response.body).not_to include(license.encrypted_key)

    get admin_subscription_audit_path(user)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Settled payment totals")
    expect(response.body).to include("Pandora licenses")
    expect(response.body).to include("Chu Sniper Trailing")
    expect(response.body).not_to include(license.encrypted_key)
    expect(response.body).not_to include(chu_license.encrypted_key)
    expect(response.body).not_to include("encrypted_key")

    get admin_subscription_audits_path(format: :csv)
    expect(response.status).to be_in([ 401, 406 ])
    expect(response.body).not_to include(license.encrypted_key)
  end

  it "renders Spanish operational copy" do
    admin = create(:user, :admin)
    user, = create_subscribed_user
    sign_in admin, scope: :user

    get admin_subscription_audit_path(user, locale: :es)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Totales de pagos liquidados")
    expect(response.body).to include("Licencias de Pandora")
  end

  it "blocks non-admin roles from the audit section" do
    user, = create_subscribed_user

    %i[trader partner full_trader].each do |role|
      actor = create(:user, role: role)
      sign_in actor, scope: :user
      get admin_subscription_audit_path(user)
      expect(response).to redirect_to(root_path)
      sign_out :user
    end
  end

  it "rotates only one user's subscription licenses and deduplicates repeated submission" do
    admin = create(:user, :admin)
    user, = create_subscribed_user
    other_user, = create_subscribed_user
    subscription_license = create(
      :license,
      user: user,
      expert_advisor: pandora_ea,
      status: "active",
      trial_ends_at: nil,
      expires_at: 1.month.from_now
    )
    other_ea = create(:expert_advisor)
    one_time_license = create(:license, :one_time, user: user, expert_advisor: other_ea)
    other_license = create(
      :license,
      user: other_user,
      expert_advisor: create(:expert_advisor),
      status: "active",
      trial_ends_at: nil,
      expires_at: 1.month.from_now
    )
    request_id = SecureRandom.uuid
    sign_in admin, scope: :user

    2.times do
      post rotate_subscription_licenses_admin_subscription_audit_path(user), params: { request_id: request_id }
      expect(response).to redirect_to(admin_subscription_audit_path(user))
    end

    expect(subscription_license.reload.token_version).to eq(2)
    expect(one_time_license.reload.token_version).to eq(1)
    expect(other_license.reload.token_version).to eq(1)
    expect(AdminAuditEvent.where(request_id: request_id).count).to eq(1)
  end

  it "forbids admins from global rotation and allows a confirmed master-admin operation once" do
    admin = create(:user, :admin)
    master_admin = create(:user, :master_admin)
    user, = create_subscribed_user
    license = create(
      :license,
      user: user,
      expert_advisor: pandora_ea,
      status: "active",
      trial_ends_at: nil,
      expires_at: 1.month.from_now
    )

    sign_in admin, scope: :user
    post rotate_all_admin_subscription_audits_path,
         params: { request_id: SecureRandom.uuid, confirmation: "ROTATE ALL" }
    expect(response).to have_http_status(:forbidden)
    expect(license.reload.token_version).to eq(1)

    sign_out :user
    sign_in master_admin, scope: :user
    get confirm_rotate_all_admin_subscription_audits_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("ROTATE ALL")

    request_id = SecureRandom.uuid
    2.times do
      post rotate_all_admin_subscription_audits_path,
           params: { request_id: request_id, confirmation: "ROTATE ALL" }
      expect(response).to redirect_to(admin_subscription_audits_path)
    end

    expect(license.reload.token_version).to eq(2)
    expect(AdminAuditEvent.where(request_id: request_id).count).to eq(1)
  end

  it "creates one audited manual grant for repeated form submissions" do
    admin = create(:user, :admin)
    user = create(:user)
    plan
    request_id = SecureRandom.uuid
    params = {
      manual_subscription: {
        user_id: user.id,
        billing_plan_id: plan.id,
        granted_days: 30,
        request_id: request_id
      }
    }
    sign_in admin, scope: :user

    2.times do
      post admin_manual_subscriptions_path, params: params
      expect(response).to redirect_to(admin_manual_subscription_path(ManualSubscription.last))
    end

    expect(user.manual_subscriptions.count).to eq(1)
    event = AdminAuditEvent.find_by!(request_id: request_id)
    expect(event.action).to eq(AdminAuditEvent::ACTIONS.fetch(:manual_subscription_granted))
    expect(event.target).to eq(user)
  end

  private

  def create_subscribed_user
    user = create(:user)
    customer = Pay::Customer.create!(
      owner: user,
      processor: "stripe",
      processor_id: "cus_#{SecureRandom.hex(5)}",
      default: true
    )
    subscription = Pay::Subscription.create!(
      customer: customer,
      name: "default",
      processor_id: "sub_#{SecureRandom.hex(5)}",
      processor_plan: plan.stripe_price_id,
      status: "active",
      quantity: 1,
      current_period_start: 1.day.ago,
      current_period_end: 1.month.from_now
    )
    Pay::Charge.create!(
      customer: customer,
      subscription: subscription,
      processor_id: "ch_#{SecureRandom.hex(5)}",
      amount: 7900,
      currency: "usd"
    )
    [ user, subscription ]
  end
end
