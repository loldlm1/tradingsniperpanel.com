class PartnerPayoutRequestsMailer < ApplicationMailer
  helper_method :detail_rows

  before_action :assign_request

  def request_notification
    @partner = @partner_payout_request.partner_profile.user
    @formatted_total = formatted_amount(@partner_payout_request.total_cents, commission_currency)

    mail(
      to: internal_recipients,
      subject: I18n.t("partner_payout_requests_mailer.request_notification.subject", app_short_name: email_subject_brand)
    )
  end

  private

  def assign_request
    @partner_payout_request = params[:partner_payout_request]
    raise ArgumentError, "partner_payout_request param is required" unless @partner_payout_request.is_a?(PartnerPayoutRequest)
  end

  def internal_recipients
    recipients = ENV.fetch("PARTNER_PAYOUT_REQUEST_RECIPIENTS", "")
                    .split(",")
                    .map(&:strip)
                    .reject(&:blank?)
    raise ArgumentError, "PARTNER_PAYOUT_REQUEST_RECIPIENTS is not configured" if recipients.empty?

    recipients
  end

  def detail_rows
    [
      { label: I18n.t("partner_payout_requests_mailer.request_notification.request_id"), value: @partner_payout_request.id },
      { label: I18n.t("partner_payout_requests_mailer.request_notification.partner_name"), value: @partner.name.presence || @partner.email },
      { label: I18n.t("partner_payout_requests_mailer.request_notification.partner_email"), value: @partner.email },
      { label: I18n.t("partner_payout_requests_mailer.request_notification.partner_id"), value: @partner.id },
      { label: I18n.t("partner_payout_requests_mailer.request_notification.referral_code"), value: @partner_payout_request.partner_profile.referral_code },
      { label: I18n.t("partner_payout_requests_mailer.request_notification.amount"), value: @formatted_total },
      { label: I18n.t("partner_payout_requests_mailer.request_notification.requested_at"), value: I18n.l(@partner_payout_request.requested_at || @partner_payout_request.created_at, format: :long) },
      { label: I18n.t("partner_payout_requests_mailer.request_notification.notification_status"), value: @partner_payout_request.notification_status }
    ]
  end

  def commission_currency
    @partner_payout_request.partner_profile.partner_commissions.where(payout_request: @partner_payout_request).pick(:currency).presence || "usd"
  end

  def formatted_amount(amount_cents, currency)
    Pay::Currency.format(amount_cents.to_i, currency: currency.to_s.presence || "usd")
  rescue StandardError
    ActiveSupport::NumberHelper.number_to_currency(amount_cents.to_f / 100.0)
  end
end
