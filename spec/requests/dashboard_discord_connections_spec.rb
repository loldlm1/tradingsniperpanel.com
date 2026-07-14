require "rails_helper"

RSpec.describe "Dashboard Discord connection", type: :request do
  include ActiveJob::TestHelper

  let(:user) { create(:user, preferred_locale: "en") }
  let(:configuration) do
    Struct.new(:support_url, keyword_init: true).new(support_url: "https://discord.gg/community")
  end

  before do
    clear_enqueued_jobs
    sign_in user, scope: :user
    allow(Discord).to receive(:enabled?).and_return(true)
    allow(Discord).to receive(:configuration).and_return(configuration)
  end

  after do
    clear_enqueued_jobs
  end

  it "renders the eligible unlinked page with a connect action and safe benefit copy" do
    stub_eligibility(true)

    get dashboard_discord_connection_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(
      I18n.t("dashboard.discord.states.eligible_unlinked.title"),
      I18n.t("dashboard.discord.actions.connect"),
      I18n.t("dashboard.discord.benefits.recorded_courses.title")
    )
  end

  it "clears the desired plan only after authoritative eligibility is present" do
    stub_eligibility(true)
    create(
      :billing_plan,
      tier: Billing::PandoraPricing::TIER,
      key: Billing::PandoraPricing::MONTHLY_KEY,
      amount_cents: Billing::PandoraPricing::MONTHLY_CENTS
    )
    get dashboard_plans_path(price_key: Billing::PandoraPricing::MONTHLY_KEY)
    expect(cookies["desired_plan"]).to be_present

    get dashboard_discord_connection_path

    expect(cookies["desired_plan"]).to be_blank
  end

  it "renders an ineligible recovery path to Pandora plans" do
    stub_eligibility(false)

    get dashboard_discord_connection_path(locale: :es)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(
      I18n.t("dashboard.discord.states.ineligible.title", locale: :es),
      I18n.t("dashboard.discord.actions.view_plans", locale: :es)
    )
  end

  it "treats a checkout success query as non-authoritative payment-pending presentation" do
    stub_eligibility(false)

    expect do
      get dashboard_discord_connection_path(locale: :es, checkout: "success")
    end.not_to have_enqueued_job(Discord::SyncVipRoleJob)

    expect(response.body).to include(
      I18n.t("dashboard.discord.states.activation_pending.title", locale: :es)
    )
    expect(response.body).not_to include(I18n.t("dashboard.discord.actions.connect", locale: :es))
    expect(user.reload.discord_connection).to be_nil
  end

  it "shows safe identity data and never renders provider IDs or error internals" do
    stub_eligibility(true)
    connection = create(
      :discord_connection,
      :connected,
      user: user,
      discord_username: "safe-name",
      discord_global_name: "Safe Display",
      vip_role_state: "granted",
      last_error_code: "forbidden"
    )

    get dashboard_discord_connection_path

    expect(response.body).to include("Safe Display")
    expect(response.body).not_to include(connection.discord_user_id, "forbidden")
  end

  it "queues a retry only for the current user's connection" do
    stub_eligibility(true)
    connection = create(:discord_connection, :connected, user: user, sync_status: "failed")
    other = create(:discord_connection, :connected)

    expect do
      post retry_dashboard_discord_connection_path
    end.to have_enqueued_job(Discord::SyncVipRoleJob).with(connection.id)

    expect(enqueued_jobs.map { |job| job.fetch(:args) }).not_to include([ other.id ])
    expect(response).to redirect_to(dashboard_discord_connection_path)
  end

  it "marks unlink pending through a CSRF-safe non-GET action" do
    stub_eligibility(true)
    connection = create(:discord_connection, :connected, user: user, vip_role_state: "granted")

    expect do
      delete unlink_dashboard_discord_connection_path
    end.to have_enqueued_job(Discord::SyncVipRoleJob).with(connection.id)

    expect(connection.reload.disconnect_requested_at).to be_present
    expect(response).to redirect_to(dashboard_discord_connection_path)
  end

  it "requires authentication for the page and mutation actions" do
    sign_out user

    get dashboard_discord_connection_path
    expect(response).to redirect_to(new_user_session_path)

    post retry_dashboard_discord_connection_path
    expect(response).to redirect_to(new_user_session_path)

    delete unlink_dashboard_discord_connection_path
    expect(response).to redirect_to(new_user_session_path)
  end

  def stub_eligibility(eligible)
    result = Discord::VipEligibility::Result.new(
      eligible: eligible,
      source: eligible ? :stripe : nil,
      plan_key: eligible ? Billing::PandoraPricing::MONTHLY_KEY : nil,
      reason: eligible ? "eligible_stripe" : "no_subscription"
    )
    eligibility = instance_double(Discord::VipEligibility, call: result)
    allow(Discord::VipEligibility).to receive(:new).with(user: user).and_return(eligibility)
  end
end
