ActiveAdmin.register_page "Dashboard" do
  menu priority: 1, label: proc { I18n.t("active_admin.dashboard.title") }

  content title: proc { I18n.t("active_admin.dashboard.title") } do
    periods = Admin::Analytics::PeriodResolver::PERIOD_KEYS.map do |key|
      Admin::Analytics::PeriodResolver.new(key: key).call
    end

    columns do
      periods.each do |period|
        column do
          title = "#{period.label} (#{I18n.l(period.starts_at.to_date)} - #{I18n.l(period.ends_at.to_date)})"
          panel title do
            stats = Admin::Analytics::RevenueMetrics.new(starts_at: period.starts_at, ends_at: period.ends_at).call
            split = Admin::Analytics::RevenueSplit.new(net_cents: stats.net_cents, as_of: period.ends_at).call
            payout = RevenueSplitPayout.for_period(period).first
            render partial: "admin/analytics/summary_table", locals: { stats: stats, split: split, payout: payout }
          end
        end
      end
    end
  end
end
