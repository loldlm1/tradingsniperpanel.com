class DashboardsController < ApplicationController
  layout "dashboard"
  before_action :authenticate_user!
  before_action :set_accessible_expert_advisors
  before_action :ensure_payment_processor, only: [:checkout, :billing_portal]
  before_action :set_subscription, only: [:show, :plans, :billing, :checkout, :cancel_scheduled_downgrade, :cancel_subscription]
  before_action :set_plan_context, only: [:show, :billing]
  before_action :set_invoices, only: [:billing]

  def show
    plan_hint = params[:price_key].presence || stored_desired_plan&.dig(:price_key)
    @overview = Dashboard::OverviewPresenter.new(
      user: current_user,
      pay_customer: @pay_customer,
      subscription: @subscription,
      plan_context: @plan_context,
      accessible_eas: @accessible_eas,
      plan_hint: plan_hint
    ).call

    clear_desired_plan if @subscription&.active?
  end

  def analytics
    @broker_analytics = Dashboard::BrokerAnalyticsPresenter.new(
      user: current_user,
      page: params[:page] || 1
    ).call
  end

  def plans
    @pricing_catalog = Billing::PricingCatalog.new.call
    @plan_context = Billing::DashboardPlan.new(
      subscription: @subscription,
      pricing_catalog: @pricing_catalog
    ).call
    @requested_price_key = params[:price_key].presence || stored_desired_plan&.dig(:price_key)
  end

  def billing; end

  def support; end

  def checkout
    price_key = params[:price_key].presence || stored_desired_plan&.dig(:price_key)
    price_id = Billing::ConfiguredPrices.price_id_for(price_key)
    unless price_id
      redirect_to dashboard_plans_path, alert: t("dashboard.billing.invalid_price") and return
    end

    if @subscription.present?
      result = Billing::PlanChange.new(
        subscription: @subscription,
        price_key: price_key,
        user: current_user
      ).call

      if result.success?
        clear_desired_plan
      end

      case result.status
      when :upgraded
        redirect_to dashboard_plans_path, notice: t("dashboard.billing.upgraded") and return
      when :downgrade_scheduled
        plan_label = plan_label_for(price_key)
        schedule_date = result.effective_at ? l(result.effective_at.to_date) : nil
        redirect_to dashboard_plans_path,
                    notice: t("dashboard.plans.downgrade_scheduled", plan: plan_label, date: schedule_date) and return
      when :already_current
        redirect_to dashboard_plans_path, alert: t("dashboard.plans.already_current") and return
      when :cannot_schedule
        redirect_to dashboard_plans_path, alert: t("dashboard.plans.downgrade_unavailable") and return
      else
        redirect_to dashboard_plans_path, alert: t("dashboard.billing.checkout_error") and return
      end
    end

    success_url = price_key.present? ? dashboard_url(price_key: price_key) : dashboard_url
    checkout_params = {
      mode: "subscription",
      line_items: [{ price: price_id, quantity: 1 }],
      success_url: success_url,
      cancel_url: dashboard_plans_url,
      allow_promotion_codes: true,
      client_reference_id: current_user.id
    }

    checkout_params = Billing::ApplyReferralDiscount.new(
      user: current_user,
      checkout_params: checkout_params
    ).call

    session = current_user.payment_processor.checkout(**checkout_params)

    redirect_to session.url, allow_other_host: true
  rescue StandardError => e
    Rails.logger.error("Checkout failed: #{e.class} - #{e.message}")
    redirect_to dashboard_plans_path, alert: t("dashboard.billing.checkout_error")
  end

  def billing_portal
    portal = current_user.payment_processor.billing_portal(return_url: dashboard_url)
    redirect_to portal.url, allow_other_host: true
  rescue StandardError => e
    Rails.logger.error("Billing portal failed: #{e.class} - #{e.message}")
    redirect_to dashboard_billing_path, alert: t("dashboard.billing.portal_error")
  end

  def cancel_scheduled_downgrade
    unless @subscription
      redirect_to dashboard_plans_path, alert: t("dashboard.plans.cancel_unavailable") and return
    end

    result = Billing::CancelScheduledPlanChange.new(subscription: @subscription).call

    case result.status
    when :canceled
      redirect_to dashboard_plans_path, notice: t("dashboard.plans.cancel_success")
    when :no_schedule
      redirect_to dashboard_plans_path, alert: t("dashboard.plans.cancel_unavailable")
    else
      redirect_to dashboard_plans_path, alert: t("dashboard.plans.cancel_error")
    end
  end

  def cancel_subscription
    unless @subscription
      redirect_to dashboard_billing_path, alert: t("dashboard.billing.cancel_unavailable") and return
    end

    result = Billing::CancelSubscription.new(subscription: @subscription, user: current_user).call

    case result.status
    when :canceled
      redirect_to dashboard_billing_path, notice: cancel_notice_for(result, key: "cancel_success")
    when :already_canceled
      redirect_to dashboard_billing_path, notice: cancel_notice_for(result, key: "cancel_already")
    when :schedule_error, :no_subscription
      redirect_to dashboard_billing_path, alert: t("dashboard.billing.cancel_error")
    else
      redirect_to dashboard_billing_path, alert: t("dashboard.billing.cancel_error")
    end
  end

  private

  def set_subscription
    return unless current_user.respond_to?(:pay_customers)

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

  def plan_label_for(price_key)
    tier, interval = price_key.to_s.split("_")
    return price_key.to_s if tier.blank?

    tier_label = t("dashboard.plans.tiers.#{tier}.name", default: tier.to_s.humanize)
    interval_key = interval.to_s == "annual" ? "annually" : interval
    interval_label = interval_key.present? ? t("dashboard.plans.toggle.#{interval_key}", default: interval.to_s.humanize) : nil

    if interval_label.present?
      t("dashboard.plan_card.plan_label", tier: tier_label, interval: interval_label)
    else
      t("dashboard.plan_card.plan_label_tier_only", tier: tier_label)
    end
  end

  def cancel_notice_for(result, key:)
    if result.ends_at.present?
      t("dashboard.billing.#{key}", date: l(result.ends_at.to_date))
    else
      t("dashboard.billing.#{key}_no_date")
    end
  end
end
