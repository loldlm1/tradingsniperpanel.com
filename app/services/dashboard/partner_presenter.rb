require "set"

module Dashboard
  class PartnerPresenter
    MONTHLY_RANGE_MONTHS = 6

    def initialize(user:, filter_email: nil)
      @user = user
      @filter_email = filter_email.to_s.strip
    end

    def call
      self
    end

    def profile
      @profile ||= user.partner_profile
    end

    def referral_code
      profile&.referral_code
    end

    def discount_percent
      profile&.discount_percent_or_default.to_i
    end

    def commission_percent
      profile&.commission_percent_or_default.to_i
    end

    def direct_referrals_scope
      scope = User.where(id: direct_referral_ids_relation)
      scope = scope.where("users.email ILIKE ?", "%#{filter_email}%") if filter_email.present?
      scope.order(created_at: :desc)
    end

    def recent_payout_requests
      profile.partner_payout_requests.order(requested_at: :desc, created_at: :desc).limit(6)
    end

    def metrics
      @metrics ||= {
        requestable_cents: pending_commissions.sum(:amount_cents),
        requested_cents: requested_commissions.sum(:amount_cents),
        paid_cents: paid_commissions.sum(:amount_cents),
        lifetime_cents: profile.partner_commissions.sum(:amount_cents),
        current_month_cents: profile.partner_commissions.where(occurred_at: Time.current.beginning_of_month..Time.current.end_of_month).sum(:amount_cents),
        subscribers_count: active_subscriber_count,
        direct_referrals_count: direct_referrals_scope.count
      }
    end

    def highlight_metrics
      [
        {
          key: :requestable,
          label: I18n.t("partner_dashboard.metrics.requestable", default: "Requestable"),
          value: currency(metrics[:requestable_cents]),
          tone: "amber"
        },
        {
          key: :requested,
          label: I18n.t("partner_dashboard.metrics.requested", default: "Requested"),
          value: currency(metrics[:requested_cents]),
          tone: "sky"
        },
        {
          key: :paid,
          label: I18n.t("partner_dashboard.metrics.paid", default: "Paid"),
          value: currency(metrics[:paid_cents]),
          tone: "emerald"
        },
        {
          key: :lifetime,
          label: I18n.t("partner_dashboard.metrics.lifetime", default: "Lifetime"),
          value: currency(metrics[:lifetime_cents]),
          tone: "slate"
        }
      ]
    end

    def chart_summary
      [
        {
          label: I18n.t("partner_dashboard.current_month", default: "Current month"),
          value: currency(metrics[:current_month_cents])
        },
        {
          label: I18n.t("partner_dashboard.direct_referrals", default: "Direct referrals"),
          value: metrics[:direct_referrals_count].to_s
        },
        {
          label: I18n.t("partner_dashboard.subscribers", default: "Subscribers"),
          value: metrics[:subscribers_count].to_s
        }
      ]
    end

    def current_request
      @current_request ||= profile.partner_payout_requests.pending.order(created_at: :desc).first
    end

    def latest_payout_request
      current_request || recent_payout_requests.first
    end

    def payout_target_cents
      Partners::PayoutRequestor::MINIMUM_PAYOUT_CENTS
    end

    def payout_remaining_cents
      [payout_target_cents - metrics[:requestable_cents], 0].max
    end

    def payout_button_disabled?
      return false if current_request&.notification_retryable?

      metrics[:requestable_cents] < payout_target_cents || current_request&.request_locked?
    end

    def payout_button_label
      return I18n.t("partner_dashboard.retry_payout_request") if current_request&.notification_retryable?
      return I18n.t("partner_dashboard.request_pending") if current_request&.request_locked?

      I18n.t("partner_dashboard.request_payout")
    end

    def payout_status_key
      if current_request&.notification_retryable?
        :notification_failed
      elsif current_request&.request_locked?
        :request_pending
      elsif metrics[:requestable_cents] < payout_target_cents
        :below_minimum
      else
        :eligible
      end
    end

    def payout_status_message
      case payout_status_key
      when :notification_failed
        I18n.t("partner_dashboard.notification_failed", default: "We could not notify the admin team. Reload and try again.")
      when :request_pending
        I18n.t("partner_dashboard.request_pending_copy", default: "Your payout request is pending review.")
      when :below_minimum
        I18n.t("partner_dashboard.minimum_remaining", amount: currency(payout_remaining_cents), default: "%{amount} remaining before you can request payout.")
      else
        I18n.t("partner_dashboard.eligible_copy", amount: currency(metrics[:requestable_cents]), default: "%{amount} is ready to request.")
      end
    end

    def monthly_paid_chart
      range_start = (MONTHLY_RANGE_MONTHS - 1).months.ago.beginning_of_month
      paid_by_month = paid_commissions.where("occurred_at >= ?", range_start)
                                     .group_by { |commission| commission.occurred_at.beginning_of_month }
                                     .transform_values { |rows| rows.sum(&:amount_cents) }

      labels = []
      data = []

      MONTHLY_RANGE_MONTHS.times do |offset|
        month = (MONTHLY_RANGE_MONTHS - offset - 1).months.ago.beginning_of_month
        labels << I18n.l(month.to_date, format: "%b")
        data << (paid_by_month[month].to_i / 100.0)
      end

      {
        labels: labels,
        values: data
      }
    end

    def referral_records_by_user_id(users)
      ids = Array(users).map(&:id)
      return {} if ids.empty?

      user.referrals.where(referee_type: "User", referee_id: ids).index_by(&:referee_id)
    end

    def active_subscription_user_ids_for(users)
      ids = Array(users).map(&:id)
      return Set.new if ids.empty?

      Set.new(
        Pay::Subscription.joins(:customer)
                         .where(pay_customers: { owner_type: "User", owner_id: ids })
                         .where(status: "active")
                         .distinct
                         .pluck("pay_customers.owner_id")
      )
    end

    private

    attr_reader :user, :filter_email

    def pending_commissions
      @pending_commissions ||= profile.partner_commissions.pending
    end

    def requested_commissions
      @requested_commissions ||= profile.partner_commissions.requested
    end

    def paid_commissions
      @paid_commissions ||= profile.partner_commissions.paid
    end

    def direct_referral_ids_relation
      user.referrals.where(referee_type: "User").select(:referee_id)
    end

    def active_subscriber_count
      Pay::Subscription.joins(:customer)
                       .where(pay_customers: { owner_type: "User", owner_id: direct_referral_ids_relation })
                       .where(status: "active")
                       .distinct
                       .count("pay_customers.owner_id")
    end

    def currency(amount_cents)
      ActiveSupport::NumberHelper.number_to_currency(amount_cents.to_i / 100.0)
    end
  end
end
