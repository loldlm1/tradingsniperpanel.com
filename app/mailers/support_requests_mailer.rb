class SupportRequestsMailer < ApplicationMailer
  helper_method :detail_rows, :message_paragraphs, :screenshot_links

  before_action :assign_support_request

  def request_notification
    I18n.with_locale(resolved_locale) do
      @preheader_text = I18n.t("support_requests_mailer.request_notification.preheader")

      mail(
        to: internal_recipients,
        subject: I18n.t("support_requests_mailer.request_notification.subject", app_short_name: email_subject_brand)
      )
    end
  end

  private

  def assign_support_request
    @support_request = params[:support_request]
    raise ArgumentError, "support_request param is required" unless @support_request.is_a?(SupportRequest)
  end

  def resolved_locale
    locale = @support_request.locale.to_s.presence || I18n.default_locale.to_s
    I18n.available_locales.map(&:to_s).include?(locale) ? locale : I18n.default_locale
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
      { label: I18n.t("support_requests_mailer.request_notification.customer_name"), value: @support_request.user.name.presence || @support_request.user.email },
      { label: I18n.t("support_requests_mailer.request_notification.customer_email"), value: @support_request.user.email },
      { label: I18n.t("support_requests_mailer.request_notification.customer_id"), value: @support_request.user_id },
      { label: I18n.t("support_requests_mailer.request_notification.locale"), value: @support_request.locale.to_s },
      { label: I18n.t("support_requests_mailer.request_notification.submitted_at"), value: I18n.l(@support_request.created_at, format: :long) }
    ]
  end

  def message_paragraphs
    @support_request.message.to_s.split(/\r?\n+/).map(&:strip).reject(&:blank?)
  end

  def screenshot_links
    @support_request.screenshots.map do |screenshot|
      {
        filename: screenshot.filename.to_s,
        url: rails_blob_url(screenshot, disposition: "attachment")
      }
    end
  end
end
