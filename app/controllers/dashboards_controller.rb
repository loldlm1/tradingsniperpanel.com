class DashboardsController < ApplicationController
  layout "dashboard"
  before_action :authenticate_user!
  before_action :set_accessible_expert_advisors
  before_action :ensure_payment_processor, only: [:checkout, :billing_portal]
  before_action :set_subscription, only: [:show, :pricing, :billing, :checkout]
  before_action :set_plan_context, only: [:show, :pricing, :billing, :checkout]
  before_action :set_invoices, only: [:billing]

  def show; end

  def analytics; end

  def pricing
    @pricing_catalog = Billing::PricingCatalog.new.call
    @requested_price_key = params[:price_key].presence || stored_desired_plan&.dig(:price_key)
  end

  def billing; end

  def support; end

  def checkout
    price_key = params[:price_key].presence || stored_desired_plan&.dig(:price_key)
    desired_tier = price_key&.split("_")&.first&.to_sym
    current_tier = @plan_context[:current_tier]

    if @subscription.present? && desired_tier && current_tier && Billing::DashboardPlan::TIERS.index(desired_tier) <= Billing::DashboardPlan::TIERS.index(current_tier)
      redirect_to dashboard_pricing_path, alert: t("dashboard.pricing.cta.current", default: "You already have this plan.") and return
    end

    price_id = Billing::ConfiguredPrices.price_id_for(price_key)
    unless price_id
      redirect_to dashboard_pricing_path, alert: t("dashboard.billing.invalid_price", default: "Invalid price selection") and return
    end

    if @subscription.present?
      @subscription.swap(price_id, prorate: true)
      clear_desired_plan
      redirect_to dashboard_pricing_path, notice: t("dashboard.billing.upgraded", default: "Your subscription has been updated.") and return
    end

    session = current_user.payment_processor.checkout(
      mode: "subscription",
      line_items: [{ price: price_id, quantity: 1 }],
      success_url: dashboard_url,
      cancel_url: dashboard_pricing_url,
      allow_promotion_codes: true,
      client_reference_id: current_user.id
    )

    clear_desired_plan
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

  def set_subscription
    @pay_customer = Pay::Customer.table_exists? ? current_user.pay_customers.first : nil
    @subscription = @pay_customer&.subscriptions&.active&.order(created_at: :desc)&.first
  end

  def set_plan_context
    @plan_context = Billing::DashboardPlan.new(subscription: @subscription).call
  end

  def set_invoices
    @invoices = @pay_customer.present? ? Pay::Charge.where(customer: @pay_customer).order(created_at: :desc).limit(20) : []
  end

  def ensure_payment_processor
    current_user.set_payment_processor(:stripe) unless current_user.payment_processor
  end
end
