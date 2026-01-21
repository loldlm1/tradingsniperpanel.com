module Dashboard
  class AnalyticsPresenter
    PNL_RANGE_DAYS = 30
    COURSE_RANGE_DAYS = 30
    ACTIVE_CHART_DAYS = 7
    REPORT_LIMIT = 8
    EA_RESULTS_LIMIT = 7

    attr_reader :pnl_range, :course_range

    def initialize(user:, filters: {}, now: Time.current)
      @user = user
      @filters = filters.to_h.symbolize_keys
      @now = now
      time_zone_name = user&.time_zone.presence
      @time_zone = time_zone_name ? ActiveSupport::TimeZone[time_zone_name] : nil
      @time_zone ||= ActiveSupport::TimeZone["UTC"]
    end

    def call
      build_ranges
      self
    end

    def datepicker_from
      pnl_range[:from_date]
    end

    def datepicker_to
      pnl_range[:to_date]
    end

    def daily_performance
      @daily_performance ||= build_daily_performance
    end

    def active_now
      @active_now ||= build_active_now
    end

    def ea_results
      @ea_results ||= build_ea_results
    end

    def course_progress
      @course_progress ||= build_course_progress
    end

    def top_eas
      @top_eas ||= build_top_eas
    end

    def latest_lessons
      @latest_lessons ||= build_latest_lessons
    end

    def expiring_licenses
      @expiring_licenses ||= build_expiring_licenses
    end

    def course_status
      @course_status ||= build_course_status
    end

    def study_time
      @study_time ||= build_study_time
    end

    def ea_types
      @ea_types ||= build_ea_types
    end

    private

    attr_reader :user, :filters, :now, :time_zone

    def build_ranges
      now_in_zone = now.in_time_zone(time_zone)
      from_date = parse_date(filters[:from_date])
      to_date = parse_date(filters[:to_date])

      if from_date.nil? || to_date.nil?
        to_date = now_in_zone.to_date
        from_date = to_date - (PNL_RANGE_DAYS - 1)
      end

      from_date, to_date = [from_date, to_date].minmax
      @pnl_range = build_range(from_date, to_date)
      @prev_pnl_range = build_range(from_date - pnl_range[:days], from_date - 1)

      course_from_time = now_in_zone - COURSE_RANGE_DAYS.days
      @course_range = {
        from_time: course_from_time,
        to_time: now_in_zone
      }

      active_from_date = now_in_zone.to_date - (ACTIVE_CHART_DAYS - 1)
      active_to_date = now_in_zone.to_date
      @active_chart_range = build_range(active_from_date, active_to_date)
    end

    def build_range(from_date, to_date)
      from_time = time_zone.local(from_date.year, from_date.month, from_date.day, 0, 0, 0)
      to_time = time_zone.local(to_date.year, to_date.month, to_date.day, 23, 59, 59)

      {
        from_date: from_date,
        to_date: to_date,
        from_ts: from_time.utc.to_i,
        to_ts: to_time.utc.to_i,
        days: (to_date - from_date).to_i + 1
      }
    end

    def parse_date(value)
      return nil if value.blank?

      Date.parse(value.to_s)
    rescue ArgumentError
      nil
    end

    def results_scope
      return BrokerAccountDailyResult.none unless user

      BrokerAccountDailyResult.joins(broker_account: { license: :expert_advisor })
                              .where(licenses: { user_id: user.id })
    end

    def results_in_range(range)
      results_scope.where(result_timestamp: range[:from_ts]..range[:to_ts])
    end

    def day_expression
      tz = ActiveRecord::Base.connection.quote(time_zone.tzinfo.name)
      "date_trunc('day', to_timestamp(broker_account_daily_results.result_timestamp) AT TIME ZONE #{tz})"
    end

    def daily_totals(range)
      results_in_range(range)
        .group(Arel.sql(day_expression))
        .sum(:result_value)
        .each_with_object({}) do |(day, value), acc|
          acc[day.to_date] = value.to_f
        end
    end

    def values_for_range(range, totals)
      (range[:from_date]..range[:to_date]).map { |date| totals[date] || 0.0 }
    end

    def labels_for_range(range)
      (range[:from_date]..range[:to_date]).map { |date| date.strftime("%Y-%m-%d") }
    end

    def cumulative_total(values)
      values.inject(0.0) { |sum, value| sum + value }
    end

    def max_drawdown(values)
      peak = 0.0
      max_draw = 0.0
      total = 0.0

      values.each do |value|
        total += value
        peak = [peak, total].max
        drawdown = peak - total
        max_draw = [max_draw, drawdown].max
      end

      max_draw
    end

    def positive_day_percent(totals)
      days_with_data = totals.size
      return 0.0 if days_with_data.zero?

      positive_days = totals.values.count { |value| value.positive? }
      (positive_days.to_f / days_with_data) * 100
    end

    def change_percent(current, previous)
      current = current.to_f
      previous = previous.to_f
      return 0.0 if current.zero? && previous.zero?
      return 100.0 if previous.zero?

      ((current - previous) / previous.abs) * 100
    end

    def trend_class(change)
      return "text-gray-500" if change.nil? || change.zero?

      change.positive? ? "text-green-600" : "text-rose-500"
    end

    def build_kpi(label:, value:, value_type:, change_percent:, hide_change: false)
      {
        label: label,
        value: value,
        value_type: value_type,
        change_percent: hide_change ? nil : change_percent,
        change_class: hide_change ? "text-gray-500" : trend_class(change_percent)
      }
    end

    def build_daily_performance
      current_totals = daily_totals(pnl_range)
      previous_totals = daily_totals(@prev_pnl_range)

      current_values = values_for_range(pnl_range, current_totals)
      previous_values = values_for_range(@prev_pnl_range, previous_totals)

      current_total = current_totals.values.sum
      previous_total = previous_totals.values.sum

      current_positive = positive_day_percent(current_totals)
      previous_positive = positive_day_percent(previous_totals)

      current_drawdown = max_drawdown(current_values)
      previous_drawdown = max_drawdown(previous_values)

      cumulative = cumulative_total(current_values)
      hide_change = current_totals.empty?

      kpis = [
        build_kpi(
          label: I18n.t("dashboard.analytics.cards.daily_performance.kpis.total_pnl"),
          value: current_total,
          value_type: :currency,
          change_percent: change_percent(current_total, previous_total),
          hide_change: hide_change
        ),
        build_kpi(
          label: I18n.t("dashboard.analytics.cards.daily_performance.kpis.cumulative_pnl"),
          value: cumulative,
          value_type: :currency,
          change_percent: change_percent(cumulative, previous_total),
          hide_change: hide_change
        ),
        build_kpi(
          label: I18n.t("dashboard.analytics.cards.daily_performance.kpis.positive_days"),
          value: current_positive,
          value_type: :percent,
          change_percent: change_percent(current_positive, previous_positive),
          hide_change: hide_change
        ),
        build_kpi(
          label: I18n.t("dashboard.analytics.cards.daily_performance.kpis.max_drawdown"),
          value: current_drawdown,
          value_type: :currency,
          change_percent: change_percent(current_drawdown, previous_drawdown),
          hide_change: hide_change
        )
      ]

      chart = if current_totals.present?
                {
                  labels: labels_for_range(pnl_range),
                  datasets: [
                    {
                      label: I18n.t("dashboard.analytics.cards.daily_performance.chart.current"),
                      data: current_values
                    },
                    {
                      label: I18n.t("dashboard.analytics.cards.daily_performance.chart.previous"),
                      data: previous_values
                    }
                  ]
                }
              end

      {
        kpis: kpis,
        chart: chart,
        has_data: current_totals.present?
      }
    end

    def build_active_now
      cutoff = (now - 24.hours).utc.to_i
      active_scope = results_scope.where("broker_account_daily_results.result_timestamp >= ?", cutoff)
      active_accounts = active_scope.distinct.count("broker_accounts.id")
      active_eas = active_scope.distinct.count("expert_advisors.id")

      top_rows = active_scope
                 .group("expert_advisors.id", "expert_advisors.name")
                 .distinct
                 .count("broker_accounts.id")
                 .sort_by { |(_, _), count| -count }
                 .first(REPORT_LIMIT)
                 .map do |(id, name), count|
        {
          id: id,
          name: name,
          count: count
        }
      end

      chart_totals = results_scope
                     .where(result_timestamp: @active_chart_range[:from_ts]..@active_chart_range[:to_ts])
                     .group(Arel.sql(day_expression))
                     .distinct
                     .count("broker_accounts.id")
                     .each_with_object({}) do |(day, value), acc|
        acc[day.to_date] = value
      end

      chart = {
        labels: labels_for_range(@active_chart_range),
        datasets: [
          {
            label: I18n.t("dashboard.analytics.cards.active_now.chart.label"),
            data: values_for_range(@active_chart_range, chart_totals)
          }
        ]
      }

      {
        active_accounts: active_accounts,
        active_eas: active_eas,
        rows: top_rows,
        chart: chart,
        has_data: active_accounts.positive? || active_eas.positive?
      }
    end

    def build_ea_results
      totals_by_ea = totals_by_ea_current
      return { labels: [], datasets: [], has_data: false } if totals_by_ea.empty?

      sorted = totals_by_ea.sort_by { |(_, value)| -value.to_f.abs }
      top_ids = sorted.first(EA_RESULTS_LIMIT).map(&:first)
      other_ids = sorted.drop(EA_RESULTS_LIMIT).map(&:first)

      names = ExpertAdvisor.where(id: top_ids).pluck(:id, :name).to_h
      labels = top_ids.map { |id| names[id] || I18n.t("dashboard.analytics.unknown_ea") }

      grouped = results_current
                .where(expert_advisors: { id: top_ids })
                .group("expert_advisors.id", "broker_accounts.account_type")
                .sum(:result_value)

      real_values = top_ids.map { |id| grouped[[id, "real"]].to_f }
      demo_values = top_ids.map { |id| grouped[[id, "demo"]].to_f }

      if other_ids.any?
        other_grouped = results_current
                        .where.not(expert_advisors: { id: top_ids })
                        .group("broker_accounts.account_type")
                        .sum(:result_value)
        labels << I18n.t("dashboard.analytics.other")
        real_values << other_grouped["real"].to_f
        demo_values << other_grouped["demo"].to_f
      end

      {
        labels: labels,
        datasets: [
          {
            label: I18n.t("dashboard.broker_accounts.account_type.real"),
            data: real_values
          },
          {
            label: I18n.t("dashboard.broker_accounts.account_type.demo"),
            data: demo_values
          }
        ],
        has_data: true
      }
    end

    def build_course_progress
      rows = course_progress_rows
      chart = {
        labels: rows.map { |row| row[:title] },
        datasets: [
          {
            label: I18n.t("dashboard.analytics.cards.course_progress.legend"),
            data: rows.map { |row| row[:progress] }
          }
        ]
      }

      {
        chart: chart,
        rows: rows,
        has_data: rows.any?
      }
    end

    def course_progress_rows
      scope = course_enrollments_scope
              .where("course_enrollments.updated_at >= ?", course_range[:from_time])
              .includes(:course)
              .order(progress_percent: :desc, updated_at: :desc)

      rows = scope.to_a
      incomplete = rows.reject { |row| row.progress_percent.to_i >= 100 }
      selected = incomplete.first(REPORT_LIMIT)
      if selected.size < REPORT_LIMIT
        remaining = rows - selected
        selected.concat(remaining.first(REPORT_LIMIT - selected.size))
      end

      selected.map do |enrollment|
        {
          title: enrollment.course&.title_for(I18n.locale),
          progress: enrollment.progress_percent.to_i
        }
      end
    end

    def build_top_eas
      totals = totals_by_ea_current
      prev_totals = totals_by_ea_previous
      return { rows: [], has_data: false } if totals.empty?

      sorted = totals.sort_by { |(_, value)| -value.to_f.abs }
      top_ids = sorted.first(REPORT_LIMIT).map(&:first)
      names = ExpertAdvisor.where(id: top_ids).pluck(:id, :name).to_h

      rows = top_ids.map do |id|
        total = totals[id].to_f
        prev_total = prev_totals[id].to_f
        {
          name: names[id] || I18n.t("dashboard.analytics.unknown_ea"),
          pnl: total,
          change_percent: change_percent(total, prev_total)
        }
      end

      max_value = rows.map { |row| row[:pnl].abs }.max.to_f
      rows.each do |row|
        row[:bar_width] = bar_width(row[:pnl].abs, max_value)
        row[:trend_class] = trend_class(row[:change_percent])
      end

      {
        rows: rows,
        has_data: rows.any?
      }
    end

    def bar_width(value, max_value, min_width: 12)
      return 0 if max_value.zero?

      width = (value.to_f / max_value) * 100
      [width.round, min_width].max
    end

    def build_latest_lessons
      rows = latest_lesson_rows
      return { rows: [], has_data: false } if rows.empty?

      max_metric = rows.map { |row| row[:metric].to_f }.max.to_f
      rows.each do |row|
        row[:bar_width] = bar_width(row[:metric], max_metric)
      end

      {
        rows: rows,
        has_data: true
      }
    end

    def latest_lesson_rows
      scope = course_lesson_progresses_scope
              .where("course_lesson_progresses.last_watched_at >= ?", course_range[:from_time])
              .includes(course_lesson: { course_module: :course })
              .order(last_watched_at: :desc)
              .limit(REPORT_LIMIT)

      scope.map do |progress|
        lesson = progress.course_lesson
        course = lesson&.course
        duration = lesson&.duration_seconds.to_i
        percent = duration.positive? ? ((progress.progress_seconds.to_f / duration) * 100).round : nil
        percent = [percent, 100].min if percent
        metric = percent || (progress.progress_seconds.to_f / 60.0)
        {
          title: I18n.t(
            "dashboard.analytics.cards.latest_lessons.lesson_label",
            course: course&.title_for(I18n.locale),
            lesson: lesson&.title_for(I18n.locale)
          ),
          progress_percent: percent,
          progress_minutes: percent.nil? ? (progress.progress_seconds.to_f / 60.0).round : nil,
          metric: metric
        }
      end
    end

    def build_expiring_licenses
      rows = expiring_license_rows
      return { rows: [], has_data: false } if rows.empty?

      max_days = rows.map { |row| row[:days_remaining] }.max.to_f
      rows.each do |row|
        row[:bar_width] = expiring_bar_width(row[:days_remaining], max_days)
      end

      {
        rows: rows,
        has_data: true
      }
    end

    def expiring_license_rows
      scope = user.licenses
                  .includes(:expert_advisor)
                  .where(status: %w[active trial])
                  .where("COALESCE(trial_ends_at, expires_at) IS NOT NULL")

      today = now.in_time_zone(time_zone).to_date

      rows = scope.map do |license|
        expires_at = license.trial? ? license.trial_ends_at : license.expires_at
        next if expires_at.blank?

        days_remaining = (expires_at.in_time_zone(time_zone).to_date - today).to_i
        next if days_remaining.negative?

        {
          name: license.expert_advisor&.name || I18n.t("dashboard.analytics.unknown_ea"),
          days_remaining: days_remaining
        }
      end.compact

      rows.sort_by { |row| row[:days_remaining] }.first(REPORT_LIMIT)
    end

    def expiring_bar_width(days_remaining, max_days)
      return 0 if max_days.zero?

      weight = 1 - (days_remaining.to_f / max_days)
      [((weight * 100).round), 12].max
    end

    def build_course_status
      scope = course_enrollments_scope.where("course_enrollments.updated_at >= ?", course_range[:from_time])

      not_started = scope.where(progress_percent: 0, completed_at: nil).count
      in_progress = scope.where("progress_percent > 0 AND progress_percent < 100 AND completed_at IS NULL").count
      completed = scope.where("completed_at IS NOT NULL OR progress_percent >= 100").count

      data = [not_started, in_progress, completed]
      labels = [
        I18n.t("dashboard.analytics.cards.course_status.labels.not_started"),
        I18n.t("dashboard.analytics.cards.course_status.labels.in_progress"),
        I18n.t("dashboard.analytics.cards.course_status.labels.completed")
      ]

      {
        labels: labels,
        datasets: [
          {
            label: I18n.t("dashboard.analytics.cards.course_status.title"),
            data: data
          }
        ],
        has_data: data.sum.positive?
      }
    end

    def build_study_time
      scope = course_lesson_progresses_scope
              .where("course_lesson_progresses.last_watched_at >= ?", course_range[:from_time])
              .joins(course_lesson: { course_module: :course })

      totals = scope.group("courses.category").sum(:progress_seconds)
      return { labels: [], datasets: [], has_data: false } if totals.empty?

      sorted = totals.sort_by { |(_, seconds)| -seconds.to_f }
      top = sorted.first(5)
      remainder = sorted.drop(5)

      labels = []
      data = []

      top.each do |(category, seconds)|
        labels << category_label(category)
        data << (seconds.to_f / 60.0).round(1)
      end

      if remainder.any?
        other_seconds = remainder.sum { |(_, seconds)| seconds.to_f }
        labels << I18n.t("dashboard.analytics.cards.study_time.other")
        data << (other_seconds / 60.0).round(1)
      end

      {
        labels: labels,
        datasets: [
          {
            label: I18n.t("dashboard.analytics.cards.study_time.title"),
            data: data
          }
        ],
        has_data: data.sum.positive?
      }
    end

    def category_label(category)
      return I18n.t("dashboard.analytics.cards.study_time.uncategorized") if category.blank?

      category.to_s
    end

    def build_ea_types
      scope = user.licenses
                  .active_or_trial
                  .joins(:expert_advisor)

      counts = scope.group("expert_advisors.ea_type").count
      labels = []
      data = []

      ea_type_labels.each do |key, label|
        count = counts[key].to_i
        next if count.zero?

        labels << label
        data << count
      end

      {
        labels: labels,
        datasets: [
          {
            label: I18n.t("dashboard.analytics.cards.ea_types.title"),
            data: data
          }
        ],
        has_data: data.sum.positive?
      }
    end

    def ea_type_labels
      {
        "ea_robot" => I18n.t("dashboard.analytics.cards.ea_types.labels.ea_robot"),
        "ea_tool" => I18n.t("dashboard.analytics.cards.ea_types.labels.ea_tool"),
        "indicator" => I18n.t("dashboard.analytics.cards.ea_types.labels.indicator"),
        "script" => I18n.t("dashboard.analytics.cards.ea_types.labels.script")
      }
    end

    def totals_by_ea_current
      @totals_by_ea_current ||= results_current.group("expert_advisors.id").sum(:result_value)
    end

    def totals_by_ea_previous
      @totals_by_ea_previous ||= results_previous.group("expert_advisors.id").sum(:result_value)
    end

    def results_current
      @results_current ||= results_in_range(pnl_range)
    end

    def results_previous
      @results_previous ||= results_in_range(@prev_pnl_range)
    end

    def course_enrollments_scope
      CourseEnrollment.where(user: user)
    end

    def course_lesson_progresses_scope
      CourseLessonProgress.where(user: user)
    end
  end
end
