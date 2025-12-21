class Dashboard::PartnerController < ApplicationController
  layout "dashboard"
  before_action :authenticate_user!
  before_action :ensure_partner!

  def show
    @profile = current_user.partner_profile
    @memberships = memberships_scope
    @commissions = commissions_scope
    @metrics = build_metrics
    @monthly_paid = monthly_paid_data
  end

  def request_payout
    profile = current_user.partner_profile
    request = Partners::PayoutRequestor.new(partner_profile: profile).call

    if request
      flash[:notice] = t("partner_dashboard.payout_requested", default: "Payout request created. We'll contact you soon.")
    else
      flash[:alert] = t("partner_dashboard.payout_none", default: "No pending commissions to request right now.")
    end

    redirect_to dashboard_partner_path
  end

  private

  def ensure_partner!
    unless current_user.partner? && current_user.partner_profile&.active?
      redirect_to dashboard_path, alert: t("partner_dashboard.access_denied", default: "Partner access required.")
    end
  end

  def memberships_scope
    scope = current_user.partner_profile.partner_memberships.active.includes(:user)
    if params[:q].present?
      term = "%#{params[:q].strip}%"
      scope = scope.joins(:user).where("users.name ILIKE :term OR users.email ILIKE :term", term:)
    end
    scope.order("users.created_at DESC")
  end

  def commissions_scope
    current_user.partner_profile.partner_commissions.includes(:referred_user, :pay_subscription).order(occurred_at: :desc).limit(50)
  end

  def build_metrics
    profile = current_user.partner_profile
    {
      pending_cents: profile.partner_commissions.pending.sum(:amount_cents),
      requested_cents: profile.partner_commissions.requested.sum(:amount_cents),
      paid_cents: profile.partner_commissions.paid.sum(:amount_cents),
      lifetime_cents: profile.partner_commissions.sum(:amount_cents),
      current_month_cents: profile.partner_commissions.where(occurred_at: Time.current.beginning_of_month..Time.current.end_of_month).sum(:amount_cents),
      subscriber_count: active_subscriber_count(profile),
      invited_count: profile.partner_memberships.active.count
    }
  end

  def monthly_paid_data
    profile = current_user.partner_profile
    commissions = profile.partner_commissions.paid
                             .where("occurred_at >= ?", 6.months.ago.beginning_of_month)
    commissions.group_by { |c| c.occurred_at.beginning_of_month }.transform_values { |rows| rows.sum(&:amount_cents) }
  end

  def active_subscriber_count(profile)
    user_ids = profile.partner_memberships.active.pluck(:user_id)
    return 0 if user_ids.empty?

    Pay::Subscription.joins(:customer)
                     .where(pay_customers: { owner_type: "User", owner_id: user_ids })
                     .where(status: "active")
                     .distinct
                     .count("pay_customers.owner_id")
  end
end
