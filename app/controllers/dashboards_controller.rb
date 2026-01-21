class DashboardsController < ApplicationController
  layout "dashboard"
  before_action :authenticate_user!
  before_action :set_accessible_expert_advisors
  before_action :ensure_payment_processor, only: [:checkout, :billing_portal]
  before_action :set_subscription, only: [:show, :plans, :billing, :checkout, :cancel_scheduled_downgrade, :cancel_subscription, :resume_subscription]
  before_action :set_plan_context, only: [:show, :billing]
  before_action :set_invoices, only: [:billing]

  def show
    plan_hint = params[:price_key].presence || stored_desired_plan&.dig(:price_key)
    @main = Dashboard::MainPresenter.new(
      user: current_user,
      subscription: @subscription,
      plan_context: @plan_context,
      plan_hint: plan_hint,
      marketplace_available: @marketplace_available
    ).call

    clear_desired_plan if @subscription&.active?
  end

  def analytics
    filters = params.permit(:from_date, :to_date).to_h
    @analytics = Dashboard::AnalyticsPresenter.new(
      user: current_user,
      filters: filters
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
    plan = BillingPlan.active.find_by(key: price_key)
    price_id = plan&.stripe_price_id || Billing::ConfiguredPrices.price_id_for(price_key)
    unless price_id
      redirect_to dashboard_plans_path, alert: t("dashboard.billing.invalid_price") and return
    end

    if plan&.one_time?
      guard = Marketplace::PurchaseGuard.new(user: current_user, billing_plan: plan).call
      unless guard.allowed
        alert_key = guard.reason == :already_purchased ? "dashboard.marketplace.errors.already_purchased" : "dashboard.marketplace.errors.addon_requires_base"
        base_label = addonable_label(guard.addonable) || t("dashboard.marketplace.errors.addon_base_default")
        redirect_to marketplace_redirect_path(plan), alert: t(alert_key, base: base_label) and return
      end

      success_url = price_key.present? ? dashboard_url(price_key: price_key) : dashboard_url
      marketplace_product = MarketplaceProduct.find_by(billing_plan_id: plan.id)
      payment_metadata = {
        billing_plan_key: price_key
      }
      if marketplace_product
        payment_metadata[:marketplace_product_key] = marketplace_product.key
        payment_metadata[:marketplace_product_id] = marketplace_product.id.to_s
      end
      checkout_params = {
        mode: "payment",
        line_items: [{ price: price_id, quantity: 1 }],
        success_url: success_url,
        cancel_url: dashboard_plans_url,
        allow_promotion_codes: true,
        client_reference_id: current_user.id,
        payment_intent_data: {
          metadata: payment_metadata
        }
      }

      checkout_params = Billing::ApplyReferralDiscount.new(
        user: current_user,
        checkout_params: checkout_params
      ).call

      session = current_user.payment_processor.checkout(**checkout_params)
      redirect_to session.url, allow_other_host: true and return
    end

    if @subscription.present?
      if manual_subscription?
        redirect_to dashboard_plans_path, alert: t("dashboard.plans.manual_unavailable") and return
      end

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
      client_reference_id: current_user.id,
      subscription_data: {
        metadata: {
          billing_plan_key: price_key
        }
      }
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
    if manual_subscription?
      redirect_to dashboard_plans_path, alert: t("dashboard.plans.manual_unavailable") and return
    end

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
    if manual_subscription?
      redirect_to dashboard_billing_path, alert: t("dashboard.billing.manual_unavailable") and return
    end

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

  def resume_subscription
    if manual_subscription?
      redirect_to dashboard_billing_path, alert: t("dashboard.billing.manual_unavailable") and return
    end

    unless @subscription
      redirect_to dashboard_billing_path, alert: t("dashboard.billing.resume_unavailable") and return
    end

    result = Billing::ResumeSubscription.new(subscription: @subscription, user: current_user).call

    case result.status
    when :resumed
      redirect_to dashboard_billing_path, notice: t("dashboard.billing.resume_success")
    when :not_resumable, :no_subscription
      redirect_to dashboard_billing_path, alert: t("dashboard.billing.resume_unavailable")
    else
      redirect_to dashboard_billing_path, alert: t("dashboard.billing.resume_error")
    end
  end

  private

  def set_subscription
    result = Billing::ActiveSubscriptionFinder.new(user: current_user).call
    @subscription = result.subscription
    @pay_customer = result.customer if result.stripe?
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

  def manual_subscription?
    @subscription.is_a?(ManualSubscription)
  end

  def plan_label_for(price_key)
    plan = BillingPlan.for_key(price_key)
    return plan.name if plan&.one_time?

    if plan
      tier_label = t("dashboard.plans.tiers.#{plan.tier}.name", default: plan.tier.to_s.humanize)
      interval_label = Billing::IntervalLabeler.label(interval: plan.interval, interval_count: plan.interval_count)
      return t("dashboard.plan_card.plan_label_tier_only", tier: tier_label) if interval_label.blank?

      return t("dashboard.plan_card.plan_label", tier: tier_label, interval: interval_label)
    end

    parts = price_key.to_s.split("_")
    tier = parts.shift
    interval_key = parts.join("_")
    return price_key.to_s if tier.blank?

    tier_label = t("dashboard.plans.tiers.#{tier}.name", default: tier.to_s.humanize)
    interval_label = Billing::IntervalLabeler.legacy_label(interval_key)
    return t("dashboard.plan_card.plan_label_tier_only", tier: tier_label) if interval_label.blank?

    t("dashboard.plan_card.plan_label", tier: tier_label, interval: interval_label)
  end

  def cancel_notice_for(result, key:)
    if result.ends_at.present?
      t("dashboard.billing.#{key}", date: l(result.ends_at.to_date))
    else
      t("dashboard.billing.#{key}_no_date")
    end
  end

  def marketplace_redirect_path(plan)
    product = MarketplaceProduct.find_by(billing_plan_id: plan.id)
    return dashboard_marketplace_path(locale: I18n.locale) unless product

    dashboard_marketplace_product_path(product, locale: I18n.locale)
  end

  def addonable_label(addonable)
    return nil unless addonable
    return addonable.name if addonable.is_a?(ExpertAdvisor)
    return addonable.title_for(I18n.locale) if addonable.respond_to?(:title_for)

    addonable.to_s
  end
end
