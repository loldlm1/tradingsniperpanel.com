module PartnerDashboardHelper
  def referral_share_url(profile)
    return if profile.blank? || profile.referral_code.blank?

    root_url(locale: localized_root_locale, Refer.param_name => profile.referral_code)
  end

  def tone_class(tone)
    case tone
    when "emerald" then "bg-emerald-500"
    when "amber" then "bg-amber-500"
    when "blue" then "bg-blue-500"
    else "bg-gray-500"
    end
  end

  def active_subscription_for?(user, active_subscription_user_ids)
    active_subscription_user_ids.include?(user.id)
  end

  def partner_request_badge_class(request)
    return "bg-emerald-100 text-emerald-800 dark:bg-emerald-500/20 dark:text-emerald-100" if request&.notification_sent?
    return "bg-rose-100 text-rose-800 dark:bg-rose-500/20 dark:text-rose-100" if request&.notification_failed?

    "bg-amber-100 text-amber-800 dark:bg-amber-500/20 dark:text-amber-100"
  end

  def localized_root_locale
    return nil if I18n.locale == I18n.default_locale

    I18n.locale
  end
end
