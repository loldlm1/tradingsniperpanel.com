module Dashboard
  class OverviewPresenter
    Activity = Struct.new(:title, :subtitle, :occurred_at, :tone, keyword_init: true)

    def initialize(user:, pay_customer:, subscription:, plan_context:, accessible_eas:)
      @user = user
      @pay_customer = pay_customer
      @subscription = subscription
      @plan_context = plan_context
      @accessible_eas = accessible_eas
    end

    def call
      self
    end

    def plan
      {
        tier: plan_context[:current_tier],
        interval: plan_context[:current_interval],
        price_key: plan_context[:current_price_key],
        status: subscription&.active? ? :active : :inactive,
        renews_at: subscription&.respond_to?(:current_period_end) ? subscription.current_period_end : nil
      }
    end

    def stat_tiles
      [
        {
          label: I18n.t("dashboard.stats.charges_30d"),
          value: currency(charges_last_30_days_cents),
          hint: I18n.t("dashboard.stats.charges_hint")
        },
        {
          label: I18n.t("dashboard.stats.active_licenses"),
          value: active_licenses_count,
          hint: I18n.t("dashboard.stats.active_hint")
        },
        {
          label: I18n.t("dashboard.stats.trials_ending"),
          value: trials_ending_soon_count,
          hint: I18n.t("dashboard.stats.trials_hint")
        },
        {
          label: I18n.t("dashboard.stats.expert_advisors"),
          value: accessible_eas.count(&:accessible),
          hint: I18n.t("dashboard.stats.expert_advisors_hint")
        }
      ]
    end

    def broker_summary
      {
        total: broker_accounts.count,
        real: broker_accounts.count(&:real?),
        demo: broker_accounts.count(&:demo?)
      }
    end

    def activity_feed
      charges = recent_charges.map do |charge|
        Activity.new(
          title: I18n.t("dashboard.activity.charge_title", default: "Charge"),
          subtitle: charge_subtitle(charge),
          occurred_at: charge.created_at,
          tone: charge.data["status"] == "succeeded" ? :success : :warning
        )
      end

      license_events + charges
    end

    private

    attr_reader :user, :pay_customer, :subscription, :plan_context, :accessible_eas

    def license_events
      licenses = user.licenses.includes(:expert_advisor)
      latest = licenses.sort_by { |license| license.updated_at || license.created_at }.last(3)

      latest.map do |license|
        status_key = license.status.to_s
        Activity.new(
          title: license.expert_advisor&.name || I18n.t("dashboard.activity.license_title"),
          subtitle: I18n.t("dashboard.activity.license_status", status: status_key.humanize),
          occurred_at: license.updated_at || license.created_at,
          tone: license.active? ? :success : :muted
        )
      end
    end

    def recent_charges
      return Pay::Charge.none unless pay_customer

      Pay::Charge.where(customer: pay_customer).order(created_at: :desc).limit(5)
    end

    def charges_last_30_days_cents
      return 0 unless pay_customer

      Pay::Charge.where(customer: pay_customer)
                 .where("created_at >= ?", 30.days.ago)
                 .sum(:amount)
    end

    def broker_accounts
      @broker_accounts ||= begin
        licenses = user.licenses.includes(:broker_accounts)
        licenses.flat_map(&:broker_accounts)
      end
    end

    def active_licenses_count
      user.licenses.where(status: %w[active trial]).count
    end

    def trials_ending_soon_count
      user.licenses.trial.where("trial_ends_at BETWEEN ? AND ?", Time.current, 7.days.from_now).count
    end

    def currency(cents)
      ActionController::Base.helpers.number_to_currency((cents || 0) / 100.0, unit: "$", precision: 2)
    end
  end
end
