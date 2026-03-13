class Dashboard::PartnerController < ApplicationController
  layout "dashboard"
  before_action :authenticate_user!
  before_action :ensure_partner!
  before_action :build_partner_dashboard, only: :show

  def show
    @profile = @partner_dashboard.profile
    @metrics = @partner_dashboard.metrics
    @current_request = @partner_dashboard.current_request
    @chart_data = @partner_dashboard.monthly_paid_chart
    @commissions = @partner_dashboard.recent_commissions
    @pagy, @direct_referrals = pagy(@partner_dashboard.direct_referrals_scope, limit: 10)
    @direct_referral_records = @partner_dashboard.referral_records_by_user_id(@direct_referrals)
    @active_subscription_user_ids = @partner_dashboard.active_subscription_user_ids_for(@direct_referrals)
  end

  def request_payout
    profile = current_user.partner_profile
    result = Partners::PayoutRequestor.new(partner_profile: profile).call

    case result.status
    when :created
      flash[:notice] = t("partner_dashboard.payout_requested", default: "Payout request queued. We'll notify the admin team now.")
    when :retried
      flash[:notice] = t("partner_dashboard.payout_retry_queued", default: "Retrying the payout request email now.")
    when :already_pending
      flash[:notice] = t("partner_dashboard.request_pending_copy", default: "Your payout request is already pending review.")
    when :below_minimum
      flash[:alert] = t("partner_dashboard.payout_minimum", amount: helpers.number_to_currency(result.total_cents.to_i / 100.0), default: "At least $200 in pending commissions is required before requesting payout.")
    when :notification_failed
      flash[:alert] = t("partner_dashboard.notification_failed", default: "We could not notify the admin team. Please reload and try again.")
    else
      flash[:alert] = t("partner_dashboard.payout_none", default: "No pending commissions are eligible right now.")
    end

    redirect_to dashboard_partner_path
  end

  private

  def ensure_partner!
    unless current_user.partner_profile&.active?
      redirect_to dashboard_path, alert: t("partner_dashboard.access_denied", default: "Partner access required.")
    end
  end

  def build_partner_dashboard
    @partner_dashboard = Dashboard::PartnerPresenter.new(
      user: current_user,
      filter_email: params[:q]
    ).call
  end
end
