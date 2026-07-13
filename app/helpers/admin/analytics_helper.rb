module Admin
  module AnalyticsHelper
    def admin_currency_from_cents(cents, currency: "usd")
      normalized_currency = currency.to_s.downcase.presence || "usd"
      unit = normalized_currency == "usd" ? "$" : "#{normalized_currency.upcase} "
      number_to_currency(BigDecimal((cents || 0).to_i.to_s) / 100, unit: unit, precision: 2)
    end

    def admin_payout_status_label(payout)
      return t("active_admin.dashboard.metrics.payout_unpaid") unless payout&.paid?

      date = payout.paid_at ? l(payout.paid_at.to_date) : l(Time.current.to_date)
      t("active_admin.dashboard.metrics.payout_paid_on", date: date)
    end
  end
end
