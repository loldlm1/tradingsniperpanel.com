module PartnerDashboardHelper
  def tone_class(tone)
    case tone
    when "emerald" then "bg-emerald-500"
    when "amber" then "bg-amber-500"
    when "blue" then "bg-blue-500"
    else "bg-gray-500"
    end
  end

  def subscription_for(user)
    customer = user.pay_customers.first
    return nil unless customer

    customer.subscriptions.active.order(created_at: :desc).first
  end
end
