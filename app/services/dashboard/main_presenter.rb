module Dashboard
  class MainPresenter
    DAY_EXPRESSION = "date_trunc('day', to_timestamp(broker_account_daily_results.result_timestamp) AT TIME ZONE 'UTC')"
    RANGE_DAYS = 30
    TOP_EA_SERIES = 3
    SUMMARY_ROWS = 5
    MAIN_LINE_PALETTE = [
      { color: "#8470FF", legend_class: "bg-violet-500" },
      { color: "#F59E0B", legend_class: "bg-amber-500" },
      { color: "#64748B", legend_class: "bg-slate-500" }
    ].freeze
    BALANCE_PIE_PALETTE = [
      { color: "#4BD37D", legend_class: "bg-emerald-400" },
      { color: "#F7CD4C", legend_class: "bg-amber-400" },
      { color: "#7BC8FF", legend_class: "bg-sky-400" },
      { color: "#8470FF", legend_class: "bg-violet-500" }
    ].freeze
    DONUT_PALETTE = [
      { color: "#6366F1", legend_class: "bg-indigo-500" },
      { color: "#F59E0B", legend_class: "bg-amber-500" },
      { color: "#14B8A6", legend_class: "bg-teal-500" },
      { color: "#EF4444", legend_class: "bg-rose-500" },
      { color: "#0EA5E9", legend_class: "bg-sky-500" },
      { color: "#8B5CF6", legend_class: "bg-violet-500" }
    ].freeze
    MINI_LINE_COLOR = "#94A3B8"
    MINI_LINE_POSITIVE = "#3EC972"
    MINI_LINE_NEGATIVE = "#FF5656"
    LICENSE_LINE_COLOR = "#8470FF"
    COURSE_LINE_COLOR = "#3EC972"
    SPARKLINE_POSITIVE = "#3EC972"
    SPARKLINE_NEGATIVE = "#FF5656"

    def initialize(user:, subscription:, plan_context:, plan_hint: nil, marketplace_available: false, now: Time.current)
      @user = user
      @subscription = subscription
      @plan_context = plan_context
      @plan_hint = plan_hint
      @marketplace_available = marketplace_available
      @now = now
    end

    def call
      self
    end

    def intro
      {
        total_pnl: currency(pnl_all_time),
        brokers: top_brokers
      }
    end

    def pnl_summary
      {
        total: currency(pnl_30_days_total),
        average: currency(pnl_30_days_average),
        chart: pnl_chart
      }
    end

    def plan_details
      plan = plan_summary
      plan_obj = BillingPlan.for_key(plan[:price_key])
      price_amount = plan_obj ? currency_with_code(plan_obj.amount_cents, plan_obj.currency) : nil
      interval_label = plan_obj&.per_label || interval_label_from_key(plan[:interval])
      benefits = plan_benefits_for(plan[:tier])

      {
        label: plan[:label],
        status: plan[:status],
        status_label: plan_status_label(plan[:status]),
        status_class: plan_status_class(plan[:status]),
        price_amount: price_amount,
        price_interval: interval_label,
        renews_at: plan[:renews_at],
        scheduled_change: plan[:scheduled_change],
        benefits: benefits,
        usage: license_usage,
        cta: plan_cta
      }
    end

    def licenses_card
      {
        active_count: active_licenses_count,
        trial_count: trial_licenses_count,
        renewal_at: renewal_at,
        chart: licenses_activity_chart(color: LICENSE_LINE_COLOR)
      }
    end

    def course_progress_card
      enrollment = course_progress_enrollment
      {
        progress_percent: enrollment&.progress_percent,
        course_title: enrollment&.course&.title_for(I18n.locale),
        chart: course_progress_chart(color: COURSE_LINE_COLOR)
      }
    end

    def balance_distribution
      {
        total: currency(pnl_30_days_total),
        chart: broker_distribution_chart,
        legend: broker_distribution_legend
      }
    end

    def mini_cards
      [
        build_mini_card(
          key: :broker_accounts,
          total: broker_accounts_count,
          today: broker_accounts_today,
          yesterday: broker_accounts_yesterday,
          chart: broker_accounts_chart(color: MINI_LINE_NEGATIVE)
        ),
        build_mini_card(
          key: :active_eas,
          total: active_eas_in_use_count,
          today: licenses_today,
          yesterday: licenses_yesterday,
          chart: licenses_activity_chart(color: MINI_LINE_POSITIVE)
        ),
        build_mini_card(
          key: :active_licenses,
          total: active_licenses_count,
          today: licenses_today,
          yesterday: licenses_yesterday,
          chart: licenses_activity_chart(color: MINI_LINE_POSITIVE)
        ),
        build_mini_card(
          key: :courses_in_progress,
          total: courses_in_progress_count,
          today: enrollments_today,
          yesterday: enrollments_yesterday,
          chart: enrollments_chart(color: MINI_LINE_POSITIVE)
        )
      ]
    end

    def account_summary_rows
      top_ea_ids = top_ea_ids_by_pnl(limit: SUMMARY_ROWS)
      return [] if top_ea_ids.empty?

      labels = chart_labels
      ea_names = ExpertAdvisor.where(id: top_ea_ids).pluck(:id, :name).to_h
      pnl_by_ea_day = pnl_by_ea_and_day(top_ea_ids)
      totals = pnl_totals_by_ea(top_ea_ids)
      accounts = broker_accounts_by_ea(top_ea_ids)
      license_map = user.licenses.where(expert_advisor_id: top_ea_ids).index_by(&:expert_advisor_id)

      top_ea_ids.map.with_index do |ea_id, idx|
        license = license_map[ea_id]
        status = license&.status.to_s.presence || "unknown"
        palette = DONUT_PALETTE[idx % DONUT_PALETTE.size]
        name = ea_names[ea_id] || I18n.t("dashboard.main.unknown_ea", default: "Unknown EA")
        pnl_total = totals.fetch(ea_id, 0).to_f
        sparkline_color = pnl_total.negative? ? SPARKLINE_NEGATIVE : SPARKLINE_POSITIVE
        {
          id: ea_id,
          name: name,
          badge_label: name.to_s.strip.split(/\s+/).map { |part| part[0] }.join.first(2).to_s.upcase,
          badge_class: palette[:legend_class],
          status: status,
          status_label: license_status_label(status),
          status_class: license_status_class(status),
          total_accounts: accounts.fetch(ea_id, 0),
          pnl_total: currency(pnl_total),
          chart: {
            type: "line",
            labels: labels,
            datasets: [
              {
                label: "PnL",
                data: labels.map { |label| (pnl_by_ea_day.dig(ea_id, label) || 0).to_f },
                color: sparkline_color
              }
            ]
          },
          chart_id: "fintech-card-14-#{("a".ord + idx).chr}"
        }
      end
    end

    private

    attr_reader :user, :subscription, :plan_context, :plan_hint, :marketplace_available, :now

    def date_range
      @date_range ||= (from_date..to_date).to_a
    end

    def chart_labels
      @chart_labels ||= date_range.map { |date| date.strftime("%Y-%m-%d") }
    end

    def from_date
      @from_date ||= to_date - (RANGE_DAYS - 1)
    end

    def to_date
      @to_date ||= now.utc.to_date
    end

    def from_ts
      @from_ts ||= Time.utc(from_date.year, from_date.month, from_date.day).to_i
    end

    def to_ts
      @to_ts ||= Time.utc(to_date.year, to_date.month, to_date.day, 23, 59, 59).to_i
    end

    def results_scope
      @results_scope ||= BrokerAccountDailyResult
                         .joins(broker_account: { license: :expert_advisor })
                         .where(licenses: { user_id: user.id })
    end

    def range_results
      @range_results ||= results_scope.in_range(from_ts, to_ts)
    end

    def pnl_all_time
      @pnl_all_time ||= results_scope.sum(:result_value) || BigDecimal("0")
    end

    def pnl_30_days_total
      @pnl_30_days_total ||= range_results.sum(:result_value) || BigDecimal("0")
    end

    def pnl_30_days_average
      days = date_range.size
      return BigDecimal("0") if days.zero?

      pnl_30_days_total / days
    end

    def top_brokers
      totals = range_results.group("broker_accounts.company").sum(:result_value)
      totals.sort_by { |_, value| -value.to_f.abs }.first(3).map(&:first)
    end

    def pnl_chart
      top_ea_ids = top_ea_ids_by_pnl(limit: TOP_EA_SERIES)
      return nil if top_ea_ids.empty?

      ea_names = ExpertAdvisor.where(id: top_ea_ids).pluck(:id, :name).to_h
      pnl_by_ea_day = pnl_by_ea_and_day(top_ea_ids)

      datasets = top_ea_ids.each_with_index.map do |ea_id, idx|
        palette = MAIN_LINE_PALETTE[idx % MAIN_LINE_PALETTE.size]
        {
          label: ea_names[ea_id] || I18n.t("dashboard.main.unknown_ea", default: "Unknown EA"),
          data: chart_labels.map { |label| (pnl_by_ea_day.dig(ea_id, label) || 0).to_f },
          color: palette[:color],
          legend_class: palette[:legend_class]
        }
      end

      {
        type: "line",
        labels: chart_labels,
        datasets: datasets
      }
    end

    def pnl_by_ea_and_day(ea_ids)
      grouped = range_results.where(expert_advisors: { id: ea_ids })
                             .group(DAY_EXPRESSION, "expert_advisors.id")
                             .sum(:result_value)

      grouped.each_with_object(Hash.new { |hash, key| hash[key] = {} }) do |((day, ea_id), value), acc|
        acc[ea_id][day.to_date.strftime("%Y-%m-%d")] = value
      end
    end

    def pnl_totals_by_ea(ea_ids)
      range_results.where(expert_advisors: { id: ea_ids })
                   .group("expert_advisors.id")
                   .sum(:result_value)
    end

    def top_ea_ids_by_pnl(limit:)
      totals = range_results.group("expert_advisors.id").sum(:result_value)
      totals.sort_by { |_, value| -value.to_f.abs }.first(limit).map(&:first)
    end

    def broker_distribution_chart
      legend = broker_distribution_legend
      return nil if legend.empty?

      {
        type: "pie",
        labels: legend.map { |entry| entry[:label] },
        datasets: [
          {
            data: legend.map { |entry| entry[:value].to_f },
            colors: legend.map { |entry| entry[:color] }
          }
        ]
      }
    end

    def broker_distribution_legend
      totals = range_results.group("broker_accounts.company").sum(:result_value)
      sorted = totals.sort_by { |_, value| -value.to_f.abs }
      return [] if sorted.empty?

      top = sorted.first(5)
      remainder = sorted.drop(5)
      if remainder.any?
        other_total = remainder.sum { |(_, value)| value.to_f }
        top << [I18n.t("dashboard.main.balance_card.other", default: "Other"), other_total]
      end

      top.each_with_index.map do |(company, total), idx|
        palette = BALANCE_PIE_PALETTE[idx % BALANCE_PIE_PALETTE.size]
        {
          label: company,
          value: total.to_f.abs,
          display_value: currency(total),
          color: palette[:color],
          legend_class: palette[:legend_class]
        }
      end
    end

    def broker_accounts_by_ea(ea_ids)
      BrokerAccount.joins(license: :expert_advisor)
                   .where(licenses: { user_id: user.id }, expert_advisors: { id: ea_ids })
                   .group("expert_advisors.id")
                   .count
    end

    def licenses_scope
      @licenses_scope ||= user.licenses
    end

    def broker_accounts_scope
      @broker_accounts_scope ||= BrokerAccount.joins(license: :expert_advisor)
                                              .where(licenses: { user_id: user.id })
    end

    def enrollments_scope
      @enrollments_scope ||= user.course_enrollments
    end

    def course_progress_enrollment
      @course_progress_enrollment ||= enrollments_scope.includes(:course)
                                                      .order(progress_percent: :desc, updated_at: :desc)
                                                      .first
    end

    def broker_accounts_count
      @broker_accounts_count ||= broker_accounts_scope.count
    end

    def active_eas_in_use_count
      @active_eas_in_use_count ||= broker_accounts_scope.distinct.count("licenses.expert_advisor_id")
    end

    def active_licenses_count
      @active_licenses_count ||= licenses_scope.where(status: %w[active trial]).count
    end

    def trial_licenses_count
      @trial_licenses_count ||= licenses_scope.where(status: "trial").count
    end

    def total_licenses_count
      @total_licenses_count ||= licenses_scope.count
    end

    def courses_in_progress_count
      @courses_in_progress_count ||= enrollments_scope.where("progress_percent < 100").count
    end

    def renewal_at
      subscription&.respond_to?(:current_period_end) ? subscription.current_period_end : nil
    end

    def license_usage
      total = total_licenses_count
      active = active_licenses_count
      percent = total.positive? ? ((active.to_f / total) * 100).round : 0
      {
        active: active,
        total: total,
        percent: percent
      }
    end

    def broker_accounts_chart(color: MINI_LINE_COLOR)
      chart_from_counts(daily_counts(broker_accounts_scope, "broker_accounts.created_at"), color)
    end

    def licenses_activity_chart(color: MINI_LINE_COLOR)
      chart_from_counts(daily_counts(licenses_scope, "licenses.created_at"), color)
    end

    def enrollments_chart(color: MINI_LINE_COLOR)
      chart_from_counts(daily_counts(enrollments_scope, "course_enrollments.created_at"), color)
    end

    def course_progress_chart(color: MINI_LINE_COLOR)
      scope = user.course_lesson_progresses.where(status: "completed")
      chart_from_counts(daily_counts(scope, "course_lesson_progresses.completed_at"), color)
    end

    def daily_counts(scope, column)
      scoped = scope.where("#{column} BETWEEN ? AND ?", from_date.beginning_of_day, to_date.end_of_day)
      grouped = scoped.group("date_trunc('day', #{column} AT TIME ZONE 'UTC')").count
      grouped.transform_keys { |day| day.to_date.strftime("%Y-%m-%d") }
    end

    def chart_from_counts(counts, color)
      {
        type: "line",
        labels: chart_labels,
        datasets: [
          {
            label: "Count",
            data: chart_labels.map { |label| counts[label].to_i },
            color: color
          }
        ]
      }
    end

    def broker_accounts_today
      @broker_accounts_today ||= broker_accounts_scope.where(created_at: day_range).count
    end

    def broker_accounts_yesterday
      @broker_accounts_yesterday ||= broker_accounts_scope.where(created_at: day_range(1.day.ago)).count
    end

    def licenses_today
      @licenses_today ||= licenses_scope.where(created_at: day_range).count
    end

    def licenses_yesterday
      @licenses_yesterday ||= licenses_scope.where(created_at: day_range(1.day.ago)).count
    end

    def enrollments_today
      @enrollments_today ||= enrollments_scope.where(created_at: day_range).count
    end

    def enrollments_yesterday
      @enrollments_yesterday ||= enrollments_scope.where(created_at: day_range(1.day.ago)).count
    end

    def day_range(day = now)
      day = day.in_time_zone("UTC")
      day.beginning_of_day..day.end_of_day
    end

    def build_mini_card(key:, total:, today:, yesterday:, chart:)
      change = change_stats(today, yesterday)
      {
        key: key,
        total: total,
        change: change,
        chart: chart
      }
    end

    def change_stats(today, yesterday)
      today = today.to_i
      yesterday = yesterday.to_i
      delta = today - yesterday
      percent = percentage_change(today, yesterday)

      {
        delta: delta,
        delta_label: delta.positive? ? "+#{delta}" : delta.to_s,
        percent: percent
      }
    end

    def percentage_change(today, yesterday)
      return 0 if today.zero? && yesterday.zero?
      return 100 if yesterday.zero?

      (((today - yesterday) / yesterday.to_f) * 100).round
    end

    def plan_summary
      price_key = plan_context[:current_price_key].presence || plan_hint_key
      hint_tier, hint_interval = parse_price_key(price_key)
      tier = plan_context[:current_tier].presence || hint_tier
      interval_key = plan_context[:current_interval_key].presence || hint_interval
      scheduled_change = scheduled_plan_change
      {
        tier: tier,
        interval: interval_key,
        price_key: price_key,
        status: plan_status(price_key),
        label: plan_label(price_key, tier: tier, interval_key: interval_key),
        renews_at: renewal_at,
        scheduled_change: scheduled_change
      }
    end

    def plan_status(price_key)
      return :active if subscription&.active?
      return :failed if subscription_failed?
      return :pending if price_key.present?

      :inactive
    end

    def subscription_failed?
      return false unless subscription

      subscription.past_due? || subscription.unpaid? || subscription.status == "incomplete_expired"
    end

    def plan_hint_key
      plan_hint.to_s.presence
    end

    def parse_price_key(price_key)
      parts = price_key.to_s.split("_")
      return [nil, nil] if parts.size < 2

      [parts.shift, parts.join("_")]
    end

    def scheduled_plan_change
      change = plan_context[:scheduled_change]
      return nil if change.blank?

      {
        price_key: change[:price_key],
        tier: change[:tier],
        interval: change[:interval_key],
        effective_at: change[:effective_at],
        label: plan_label(change[:price_key], tier: change[:tier], interval_key: change[:interval_key])
      }
    end

    def plan_label(price_key, tier:, interval_key:)
      plan = BillingPlan.for_key(price_key)
      if plan
        return plan.name if plan.one_time?

        interval_label = plan.interval_label
        return I18n.t("dashboard.plan_card.plan_label_tier_only", tier: tier_label(plan.tier)) if interval_label.blank?

        return I18n.t("dashboard.plan_card.plan_label", tier: tier_label(plan.tier), interval: interval_label)
      end

      return nil if tier.blank?

      interval_label = interval_label_from_key(interval_key)
      return I18n.t("dashboard.plan_card.plan_label_tier_only", tier: tier_label(tier)) if interval_label.blank?

      I18n.t("dashboard.plan_card.plan_label", tier: tier_label(tier), interval: interval_label)
    end

    def interval_label_from_key(interval_key)
      return nil if interval_key.blank?

      return Billing::IntervalLabeler.label(interval: "month", interval_count: 1) if interval_key == "monthly"
      return Billing::IntervalLabeler.label(interval: "year", interval_count: 1) if interval_key == "annual"

      parts = interval_key.to_s.split("_")
      count = parts.shift.to_i
      interval = parts.join("_")
      return Billing::IntervalLabeler.label(interval: interval, interval_count: count) if count.positive? && interval.present?

      Billing::IntervalLabeler.legacy_label(interval_key)
    end

    def tier_label(tier)
      I18n.t("dashboard.plans.tiers.#{tier}.name", default: tier.to_s.humanize)
    end

    def plan_benefits_for(tier)
      return [] if tier.blank?

      benefits = I18n.t("dashboard.plans.tiers.#{tier}.features", default: [])
      Array(benefits).first(3)
    end

    def plan_cta
      return get_plan_cta unless subscription.present?

      if upgrade_available?
        upgrade_plan_cta
      elsif marketplace_available
        marketplace_cta
      else
        unavailable_cta
      end
    end

    def upgrade_available?
      states = plan_context[:states]
      return false if states.blank?

      states.any? { |_, intervals| intervals.values.any? { |state| state == :upgrade } }
    end

    def get_plan_cta
      { type: :plans, label: I18n.t("dashboard.main.plan_card.cta_get_plan") }
    end

    def upgrade_plan_cta
      { type: :plans, label: I18n.t("dashboard.main.plan_card.cta_upgrade_plan") }
    end

    def marketplace_cta
      { type: :marketplace, label: I18n.t("dashboard.main.plan_card.cta_marketplace") }
    end

    def unavailable_cta
      { type: :disabled, label: I18n.t("dashboard.main.plan_card.cta_unavailable") }
    end

    def plan_status_label(status)
      case status
      when :active then I18n.t("dashboard.plan_card.status_active")
      when :pending then I18n.t("dashboard.plan_card.status_pending")
      when :failed then I18n.t("dashboard.plan_card.status_failed")
      else I18n.t("dashboard.plan_card.status_inactive")
      end
    end

    def plan_status_class(status)
      case status
      when :active
        "bg-emerald-100 text-emerald-700 dark:bg-emerald-500/20 dark:text-emerald-100"
      when :pending
        "bg-amber-100 text-amber-700 dark:bg-amber-500/20 dark:text-amber-100"
      when :failed
        "bg-rose-100 text-rose-700 dark:bg-rose-500/20 dark:text-rose-100"
      else
        "bg-amber-100 text-amber-700 dark:bg-amber-500/20 dark:text-amber-100"
      end
    end

    def license_status_label(status)
      I18n.t("dashboard.main.account_summary.status.#{status}", default: status.to_s.humanize)
    end

    def license_status_class(status)
      case status
      when "active"
        "text-green-500"
      when "trial"
        "text-amber-500"
      when "expired"
        "text-gray-500"
      when "revoked"
        "text-rose-500"
      else
        "text-gray-500"
      end
    end

    def currency(amount)
      ActionController::Base.helpers.number_to_currency((amount || 0).to_f, unit: "$", precision: 2)
    end

    def currency_with_code(amount_cents, currency_code)
      amount = amount_cents.to_f / 100.0
      precision = amount_cents.to_i % 100 == 0 ? 0 : 2
      unit = "#{currency_code.to_s.upcase} "
      ActionController::Base.helpers.number_to_currency(amount, unit: unit, precision: precision)
    end
  end
end
