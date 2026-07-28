require "rails_helper"

RSpec.describe "Dashboard subscription plans", type: :request do
  let(:user) { create(:user) }

  around do |example|
    original_key = ENV["STRIPE_PRIVATE_KEY"]
    ENV.delete("STRIPE_PRIVATE_KEY")
    example.run
  ensure
    ENV["STRIPE_PRIVATE_KEY"] = original_key
  end

  before do
    create_subscription_catalog
    sign_in user, scope: :user
  end

  it "renders both complete products in English and Spanish" do
    {
      en: [ "Subscription plans", "Chu Sniper Trailing", "Pandora Box" ],
      es: [ "Planes de suscripción", "Chu Sniper Trailing", "Pandora Box" ]
    }.each do |locale, copy|
      get dashboard_plans_path(locale: locale)

      expect(response).to have_http_status(:ok)
      copy.each { |text| expect(response.body).to include(text) }
      expect(response.body).to include("19.99", "155.92", "79.00", "616.20")
      expect(response.body).to include(":aria-pressed=\"period ===")

      tiers = Nokogiri::HTML(response.body).css("[data-plan-tier]").map { |card| card["data-plan-tier"] }
      expect(tiers).to eq([ Billing::ChuSniperPricing::TIER, Billing::PandoraPricing::TIER ])
    end
  end

  it "marks Chu as current and exposes upgrade actions for a Chu subscriber" do
    create_subscription(plan: Billing::ChuSniperPricing::MONTHLY_KEY)

    get dashboard_plans_path(locale: :en)

    expect(response).to have_http_status(:ok)
    chu_card = Nokogiri::HTML(response.body).at_css("[data-plan-tier='#{Billing::ChuSniperPricing::TIER}']")
    pandora_card = Nokogiri::HTML(response.body).at_css("[data-plan-tier='#{Billing::PandoraPricing::TIER}']")
    expect(chu_card.text).to include(I18n.t("dashboard.plans.cta.current", locale: :en))
    expect(chu_card.to_s).to include(Billing::ChuSniperPricing::ANNUAL_KEY, "data-confirm-message")
    expect(pandora_card.to_s).to include(Billing::PandoraPricing::MONTHLY_KEY, "data-confirm-message")
  end

  it "marks Pandora as current and exposes downgrade actions for a Pandora subscriber" do
    create_subscription(plan: Billing::PandoraPricing::ANNUAL_KEY)

    get dashboard_plans_path(locale: :es)

    expect(response).to have_http_status(:ok)
    chu_card = Nokogiri::HTML(response.body).at_css("[data-plan-tier='#{Billing::ChuSniperPricing::TIER}']")
    pandora_card = Nokogiri::HTML(response.body).at_css("[data-plan-tier='#{Billing::PandoraPricing::TIER}']")
    expect(pandora_card.text).to include(I18n.t("dashboard.plans.cta.current", locale: :es))
    expect(chu_card.text).to include(I18n.t("dashboard.plans.cta.downgrade", locale: :es))
    expect(response.body).not_to include("data-confirm-message")
  end

  it "renders a scheduled Chu transition on the Pandora card set" do
    create_subscription(
      plan: Billing::PandoraPricing::MONTHLY_KEY,
      metadata: {
        "scheduled_plan_key" => Billing::ChuSniperPricing::ANNUAL_KEY,
        "scheduled_change_at" => 1.month.from_now.iso8601,
        "scheduled_schedule_id" => "sub_sched_chu_spec"
      }
    )

    get dashboard_plans_path(locale: :en)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(
      I18n.t("dashboard.plans.scheduled_badge", locale: :en),
      I18n.t("dashboard.plans.tiers.chu_sniper_trailing.name", locale: :en),
      I18n.t("dashboard.plans.interval.toggle.year.one", locale: :en)
    )
  end

  private

  def create_subscription(plan:, metadata: {})
    billing_plan = BillingPlan.find_by!(key: plan)
    customer = user.pay_customers.create!(
      processor: "stripe",
      processor_id: "cus_dashboard_plans_#{user.id}",
      default: true
    )
    customer.subscriptions.create!(
      name: "default",
      processor_id: "sub_dashboard_plans_#{user.id}",
      processor_plan: billing_plan.stripe_price_id,
      status: "active",
      quantity: 1,
      current_period_start: Time.current,
      current_period_end: 1.month.from_now,
      metadata: metadata,
      type: "Pay::Stripe::Subscription"
    )
  end
end
