module Admin
  module AnalyticsHelper
    def admin_currency_from_cents(cents)
      number_to_currency((cents || 0) / 100.0, unit: "$", precision: 2)
    end
  end
end
