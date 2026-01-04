module Dashboard
  class BrokerAnalyticsPresenter
    SetupRow = Struct.new(:ea_name, :broker_name, :account_type, :total_pnl, :days_count, :last_result_at, keyword_init: true)

    DEFAULT_RANGE_DAYS = 30
    MAX_COMPARE_SERIES = 6
    DAY_EXPRESSION = "date_trunc('day', to_timestamp(broker_account_daily_results.result_timestamp) AT TIME ZONE 'UTC')"

    attr_reader :totals, :summary, :chart_data, :setups, :pagination,
                :available_brokers, :available_account_types, :filters, :compare_by_options

    def initialize(user:, page: 1, per_page: 10, filters: {})
      @user = user
      @page = [page.to_i, 1].max
      @per_page = per_page
      @filters = filters.to_h.symbolize_keys
      @compare_by_options = %w[none ea broker account_type]
    end

    def call
      accounts_scope = broker_accounts
      @available_brokers = accounts_scope.distinct.order(:company).pluck(:company).compact
      @available_account_types = BrokerAccount.account_types.keys

      normalize_filters!

      filtered_accounts = apply_account_filters(accounts_scope).to_a
      @totals = build_account_totals(filtered_accounts)

      results_scope = apply_time_range(results_for_account_ids(filtered_accounts.map(&:id)))

      @summary = build_summary(results_scope)
      @chart_data = build_chart_data(results_scope)

      @setups = paginate(build_setup_rows(filtered_accounts, results_scope))
      self
    end

    private

    attr_reader :user, :page, :per_page

    def broker_accounts
      return BrokerAccount.none unless user

      BrokerAccount.joins(license: :expert_advisor)
                   .includes(license: :expert_advisor)
                   .where(licenses: { user_id: user.id })
    end

    def results_for_account_ids(account_ids)
      return BrokerAccountDailyResult.none if account_ids.empty?

      BrokerAccountDailyResult.joins(broker_account: { license: :expert_advisor })
                              .where(broker_accounts: { id: account_ids })
    end

    def normalize_filters!
      @filters[:compare_by] = normalize_compare_by(@filters[:compare_by])
      @filters[:ea_id] = @filters[:ea_id].presence
      @filters[:broker] = @filters[:broker].presence
      @filters[:account_type] = normalize_account_type(@filters[:account_type])

      from_ts = parse_integer(@filters[:from_ts])
      to_ts = parse_integer(@filters[:to_ts])
      from_date, to_date = date_range_from_ts(from_ts, to_ts)

      @filters[:from_date] = from_date
      @filters[:to_date] = to_date
      @filters[:from_ts] = utc_day_start(from_date)
      @filters[:to_ts] = utc_day_end(to_date)
    end

    def normalize_compare_by(raw)
      value = raw.to_s
      value = "none" if value.blank?
      return value if compare_by_options.include?(value)

      "none"
    end

    def normalize_account_type(raw)
      return nil if raw.blank?

      key = raw.to_s
      return key if BrokerAccount.account_types.key?(key)

      nil
    end

    def parse_integer(raw)
      return nil if raw.blank?

      Integer(raw.to_s, 10)
    rescue ArgumentError, TypeError
      nil
    end

    def date_range_from_ts(from_ts, to_ts)
      if from_ts && to_ts
        from_date = Time.at(from_ts).utc.to_date
        to_date = Time.at(to_ts).utc.to_date
        return [from_date, to_date].sort
      end

      to_date = Time.current.utc.to_date
      from_date = to_date - (DEFAULT_RANGE_DAYS - 1)
      [from_date, to_date]
    end

    def utc_day_start(date)
      Time.utc(date.year, date.month, date.day).to_i
    end

    def utc_day_end(date)
      Time.utc(date.year, date.month, date.day, 23, 59, 59).to_i
    end

    def date_range
      @date_range ||= (filters[:from_date]..filters[:to_date]).to_a
    end

    def apply_account_filters(scope)
      scoped = scope
      scoped = scoped.where(expert_advisors: { ea_id: filters[:ea_id] }) if filters[:ea_id].present?
      scoped = scoped.where(company: filters[:broker]) if filters[:broker].present?
      scoped = scoped.where(account_type: filters[:account_type]) if filters[:account_type].present?
      scoped
    end

    def apply_time_range(scope)
      scope.where(result_timestamp: filters[:from_ts]..filters[:to_ts])
    end

    def build_account_totals(accounts)
      {
        total: accounts.size,
        real: accounts.count { |acc| acc.account_type == "real" },
        demo: accounts.count { |acc| acc.account_type == "demo" }
      }
    end

    def build_summary(scope)
      total_pnl = scope.sum(:result_value) || BigDecimal("0")
      days = date_range.size
      average = days.positive? ? (total_pnl / days) : BigDecimal("0")

      {
        total_pnl: total_pnl,
        average_daily_pnl: average,
        days: days
      }
    end

    def build_chart_data(scope)
      labels = date_range.map { |date| date.strftime("%Y-%m-%d") }
      datasets = build_datasets(scope)

      {
        labels: labels,
        datasets: datasets
      }
    end

    def build_datasets(scope)
      compare_by = effective_compare_by
      return build_total_dataset(scope) if compare_by.nil?

      datasets = build_compare_datasets(scope, compare_by)
      return build_total_dataset(scope) if datasets.empty?

      datasets
    end

    def effective_compare_by
      return nil if filters[:compare_by] == "none"
      return nil if filters[:compare_by] == "ea" && filters[:ea_id].present?
      return nil if filters[:compare_by] == "broker" && filters[:broker].present?
      return nil if filters[:compare_by] == "account_type" && filters[:account_type].present?

      filters[:compare_by]
    end

    def build_total_dataset(scope)
      totals_by_day = scope.group(DAY_EXPRESSION).sum(:result_value)
      daily_totals = totals_by_day.each_with_object({}) do |(day, value), acc|
        acc[day.to_date] = value
      end

      data = date_range.map { |date| (daily_totals[date] || 0).to_f }

      [
        {
          label: I18n.t("dashboard.analytics.chart.total_label"),
          data: data
        }
      ]
    end

    def build_compare_datasets(scope, compare_by)
      group_field = compare_group_field(compare_by)
      return [] if group_field.nil?

      group_totals = scope.group(group_field).sum(:result_value)
      top_groups = group_totals.sort_by { |_, value| -value.to_f.abs }
                               .first(MAX_COMPARE_SERIES)
                               .map(&:first)

      return [] if top_groups.empty?

      @ea_labels = ExpertAdvisor.where(id: top_groups).pluck(:id, :name).to_h if compare_by == "ea"

      grouped_scope = apply_group_filter(scope, compare_by, top_groups)
      grouped_values = grouped_scope.group(DAY_EXPRESSION, group_field).sum(:result_value)

      data_by_group = Hash.new { |hash, key| hash[key] = {} }
      grouped_values.each do |(day, group), value|
        data_by_group[group][day.to_date] = value
      end

      top_groups.map do |group|
        {
          label: compare_group_label(compare_by, group),
          data: date_range.map { |date| (data_by_group[group][date] || 0).to_f }
        }
      end
    end

    def compare_group_field(compare_by)
      case compare_by
      when "ea"
        "expert_advisors.id"
      when "broker"
        "broker_accounts.company"
      when "account_type"
        "broker_accounts.account_type"
      end
    end

    def apply_group_filter(scope, compare_by, groups)
      case compare_by
      when "ea"
        scope.where(expert_advisors: { id: groups })
      when "broker"
        scope.where(broker_accounts: { company: groups })
      when "account_type"
        scope.where(broker_accounts: { account_type: groups })
      else
        scope
      end
    end

    def compare_group_label(compare_by, group)
      case compare_by
      when "ea"
        (@ea_labels || {})[group] || group.to_s
      when "broker"
        group.to_s
      when "account_type"
        key = BrokerAccount.account_types.key(group) || group.to_s
        I18n.t("dashboard.broker_accounts.account_type.#{key}", default: key.to_s.humanize)
      else
        group.to_s
      end
    end

    def build_setup_rows(accounts, results_scope)
      totals = results_scope.group(:broker_account_id).sum(:result_value)
      day_counts = results_scope.group(:broker_account_id).count
      last_timestamps = results_scope.group(:broker_account_id).maximum(:result_timestamp)

      rows = accounts.map do |account|
        SetupRow.new(
          ea_name: account.license&.expert_advisor&.name || I18n.t("dashboard.analytics.unknown_ea"),
          broker_name: account.company,
          account_type: account.account_type,
          total_pnl: totals[account.id] || BigDecimal("0"),
          days_count: day_counts[account.id] || 0,
          last_result_at: last_timestamps[account.id] ? Time.at(last_timestamps[account.id]).utc : nil
        )
      end

      rows.sort_by { |row| -row.total_pnl.to_f.abs }
    end

    def paginate(rows)
      total_pages = (rows.count / per_page.to_f).ceil
      total_pages = 1 if total_pages.zero?
      current_page = [page, total_pages].min

      sliced = rows.slice((current_page - 1) * per_page, per_page) || []
      @pagination = {
        current_page: current_page,
        total_pages: total_pages,
        total_count: rows.count
      }

      sliced
    end
  end
end
