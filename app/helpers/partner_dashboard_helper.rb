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
    when "sky" then "bg-sky-500"
    when "rose" then "bg-rose-500"
    when "slate" then "bg-slate-500"
    else "bg-gray-500"
    end
  end

  def tone_surface_class(tone)
    case tone
    when "emerald" then "border-emerald-200/80 bg-emerald-50/70 dark:border-emerald-500/20 dark:bg-emerald-500/10"
    when "amber" then "border-amber-200/80 bg-amber-50/80 dark:border-amber-500/20 dark:bg-amber-500/10"
    when "sky" then "border-sky-200/80 bg-sky-50/80 dark:border-sky-500/20 dark:bg-sky-500/10"
    when "rose" then "border-rose-200/80 bg-rose-50/80 dark:border-rose-500/20 dark:bg-rose-500/10"
    when "slate" then "border-slate-200/80 bg-slate-100/70 dark:border-slate-600/40 dark:bg-slate-700/20"
    else "border-gray-200 bg-gray-50 dark:border-gray-700 dark:bg-gray-800/60"
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

  def payout_request_status_badge_class(request)
    return "bg-emerald-100 text-emerald-800 dark:bg-emerald-500/20 dark:text-emerald-100" if request&.paid?
    return "bg-slate-100 text-slate-700 dark:bg-slate-700/50 dark:text-slate-100" if request&.cancelled?

    "bg-amber-100 text-amber-800 dark:bg-amber-500/20 dark:text-amber-100"
  end

  def payout_request_status_label(request)
    I18n.t("partner_dashboard.payout_request_states.#{request.status}", default: request.status.humanize)
  end

  def payout_request_notification_badge_class(request)
    return "bg-emerald-100 text-emerald-800 dark:bg-emerald-500/20 dark:text-emerald-100" if request&.notification_sent?
    return "bg-rose-100 text-rose-800 dark:bg-rose-500/20 dark:text-rose-100" if request&.notification_failed?

    "bg-amber-100 text-amber-800 dark:bg-amber-500/20 dark:text-amber-100"
  end

  def payout_request_notification_label(request)
    I18n.t("partner_dashboard.notification_states.#{request.notification_status}", default: request.notification_status.humanize)
  end

  def payout_progress_percent(requestable_cents:, payout_target_cents:)
    target = payout_target_cents.to_i
    return 0 if target <= 0

    [((requestable_cents.to_f / target) * 100), 100].min.round(1)
  end

  def localized_root_locale
    return nil if I18n.locale == I18n.default_locale

    I18n.locale
  end
end
