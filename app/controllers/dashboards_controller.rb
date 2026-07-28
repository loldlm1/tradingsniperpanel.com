class DashboardsController < ApplicationController
  layout "dashboard"
  before_action :authenticate_user!
  before_action :set_accessible_expert_advisors
  before_action :ensure_payment_processor, only: [ :checkout, :billing_portal ]
  before_action :set_subscription, only: [ :show, :plans, :billing, :checkout, :cancel_scheduled_downgrade, :cancel_subscription, :resume_subscription ]
  before_action :set_plan_context, only: [ :show, :billing ]
  before_action :set_invoices, only: [ :billing ]

  def show
    plan_hint = params[:price_key].presence || stored_desired_plan&.dig(:price_key)
    @main = Dashboard::MainPresenter.new(
      user: current_user,
      subscription: @subscription,
      plan_context: @plan_context,
      plan_hint: plan_hint,
      marketplace_available: @marketplace_available
    ).call
    @discord = Dashboard::DiscordPresenter.new(user: current_user).call if Discord.enabled?

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
    @promotion_prefill = PromotionCode.active.find_by(id: params[:promotion_code_id])
  end

  def billing; end

  def support
    @support_request ||= build_support_request
  end

  def create_support_request
    @support_request = build_support_request(support_request_params)

    result = SupportRequests::CreateAndNotify.new(support_request: @support_request).call
    if result.success?
      redirect_to dashboard_support_path, notice: t("dashboard.support_submit_success")
    else
      render :support, status: :unprocessable_content
    end
  end

  def checkout
    price_key = params[:price_key].presence || stored_desired_plan&.dig(:price_key)
    plan = BillingPlan.purchasable.find_by(key: price_key)
    unless plan
      redirect_to dashboard_plans_path, alert: t("dashboard.billing.invalid_price") and return
    end
    price_id = plan.stripe_price_id

    if manual_billing_conflict?(plan)
      redirect_to dashboard_plans_path, alert: t("dashboard.plans.manual_unavailable") and return
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

    success_url = if Discord.enabled?
      dashboard_discord_connection_url(checkout: "success")
    elsif price_key.present?
      dashboard_url(price_key: price_key)
    else
      dashboard_url
    end
    checkout_params = {
      mode: "subscription",
      line_items: [ { price: price_id, quantity: 1 } ],
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

    checkout_params = Billing::ApplyDashboardPromotion.new(
      user: current_user,
      checkout_params: checkout_params,
      promotion_code_id: params[:promotion_code_id]
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
    @pay_customer = result.customer
  end

  def set_plan_context
    @plan_context = Billing::DashboardPlan.new(subscription: @subscription).call
  end

  def set_invoices
    @invoices = @pay_customer.present? ? Pay::Charge.where(customer: @pay_customer).order(created_at: :desc).limit(20) : []
  end

  def build_support_request(attributes = {})
    message = attributes[:message] || attributes["message"]
    screenshots = Array(attributes[:screenshots] || attributes["screenshots"]).reject(&:blank?)

    current_user.support_requests.new(message: message).tap do |support_request|
      support_request.locale = I18n.locale.to_s
      support_request.screenshots.attach(screenshots) if screenshots.any?
    end
  end

  def support_request_params
    params.require(:support_request).permit(:message, screenshots: [])
  end

  def ensure_payment_processor
    current_user.set_payment_processor(:stripe) unless current_user.payment_processor
  end

  def manual_subscription?
    @subscription.is_a?(ManualSubscription)
  end

  def manual_billing_conflict?(plan)
    return false unless plan && current_user

    ManualSubscription.active_at(Time.current).where(user: current_user, billing_plan_id: plan.id).exists?
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

    parsed = Billing::SubscriptionCatalog.parse_plan_key(price_key)
    tier = parsed[:tier]
    interval_key = parsed[:interval_key]
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
end
