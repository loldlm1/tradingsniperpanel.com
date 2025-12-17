class DashboardsController < ApplicationController
  layout "dashboard"
  before_action :authenticate_user!
  before_action :set_user_expert_advisors
  before_action :ensure_payment_processor, only: [:checkout, :billing_portal]
  before_action :set_subscription, only: [:show, :pricing, :billing]

  def show; end

  def analytics; end

  def pricing
    @pricing_catalog = Billing::PricingCatalog.new.call
    @plan_context = Billing::DashboardPlan.new(subscription: @subscription).call
  end

  def billing; end

  def support; end

  def checkout
    price_id = Billing::ConfiguredPrices.price_id_for(params[:price_key])
    unless price_id
      redirect_to dashboard_pricing_path, alert: t("dashboard.billing.invalid_price", default: "Invalid price selection") and return
    end

    session = current_user.payment_processor.checkout(
      mode: "subscription",
      line_items: [{ price: price_id, quantity: 1 }],
      success_url: dashboard_url,
      cancel_url: dashboard_pricing_url,
      allow_promotion_codes: true,
      client_reference_id: current_user.id
    )

    redirect_to session.url, allow_other_host: true
  rescue StandardError => e
    Rails.logger.error("Checkout failed: #{e.class} - #{e.message}")
    redirect_to dashboard_pricing_path, alert: t("dashboard.billing.checkout_error", default: "Unable to start checkout. Please try again.")
  end

  def billing_portal
    portal = current_user.payment_processor.billing_portal(return_url: dashboard_url)
    redirect_to portal.url, allow_other_host: true
  rescue StandardError => e
    Rails.logger.error("Billing portal failed: #{e.class} - #{e.message}")
    redirect_to dashboard_billing_path, alert: t("dashboard.billing.portal_error", default: "Unable to open billing portal right now.")
  end

  private

  def set_user_expert_advisors
    @user_expert_advisors = current_user.user_expert_advisors.active.includes(:expert_advisor)
  end

  def set_subscription
    @pay_customer = Pay::Customer.table_exists? ? current_user.pay_customers.first : nil
    @subscription = @pay_customer&.subscriptions&.active&.first
  end

  def ensure_payment_processor
    current_user.set_payment_processor(:stripe) unless current_user.payment_processor
  end
end
