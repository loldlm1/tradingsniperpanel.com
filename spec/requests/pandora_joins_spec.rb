require "rails_helper"

RSpec.describe "Pandora Discord join", type: :request do
  let!(:monthly_plan) do
    create(
      :billing_plan,
      tier: Billing::PandoraPricing::TIER,
      key: Billing::PandoraPricing::MONTHLY_KEY,
      amount_cents: Billing::PandoraPricing::MONTHLY_CENTS
    )
  end
  let!(:annual_plan) do
    create(
      :billing_plan,
      :annual,
      tier: Billing::PandoraPricing::TIER,
      key: Billing::PandoraPricing::ANNUAL_KEY,
      amount_cents: Billing::PandoraPricing::ANNUAL_CENTS
    )
  end

  it "stores only the canonical monthly hint and sends an anonymous Spanish visitor to sign up" do
    get pandora_join_path(locale: :es), params: { price_key: annual_plan.key }

    expect(response).to redirect_to(
      new_user_registration_path(locale: :es, price_key: monthly_plan.key)
    )
    expect(cookies["desired_plan"]).to be_present
  end

  it "sends a signed-in ineligible user to monthly plan confirmation" do
    sign_in create(:user), scope: :user

    get pandora_join_path(locale: :en)

    expect(response).to redirect_to(
      dashboard_plans_path(locale: :en, price_key: monthly_plan.key)
    )
  end

  it "sends an eligible user to their current Discord activation state" do
    allow(Discord).to receive(:enabled?).and_return(true)
    user = create(:user)
    create(:manual_subscription, user: user, billing_plan: monthly_plan)
    sign_in user, scope: :user

    get pandora_join_path(locale: :es)

    expect(response).to redirect_to(dashboard_discord_connection_path(locale: :es))
  end

  it "keeps eligible users on the dashboard while Discord activation is disabled" do
    allow(Discord).to receive(:enabled?).and_return(false)
    user = create(:user)
    create(:manual_subscription, user: user, billing_plan: monthly_plan)
    sign_in user, scope: :user

    get pandora_join_path(locale: :en)

    expect(response).to redirect_to(dashboard_path(locale: :en))
  end

  it "does not retain an injected hint when the canonical monthly plan is unavailable" do
    monthly_plan.update!(active: false)

    get pandora_join_path, params: { desired_plan: annual_plan.key }

    expect(cookies["desired_plan"]).to be_blank
  end
end
