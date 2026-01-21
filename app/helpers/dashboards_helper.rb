module DashboardsHelper
  def analytics_value(value, value_type)
    case value_type
    when :currency
      number_to_currency(value.to_f, unit: "$", precision: 2)
    when :percent
      number_to_percentage(value.to_f, precision: 0)
    else
      value.to_s
    end
  end

  def analytics_change_label(change_percent)
    return "" if change_percent.nil?

    sign = change_percent.positive? ? "+" : ""
    formatted = number_to_percentage(change_percent.to_f, precision: 0)
    "#{sign}#{formatted}"
  end
end
