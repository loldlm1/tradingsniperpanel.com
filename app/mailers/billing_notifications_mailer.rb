class BillingNotificationsMailer < ApplicationMailer
  helper_method :app_name

  before_action :assign_user
  before_action :assign_branding

  def subscription_started
    @plan_name = params[:plan_name]
    @amount = formatted_amount(params[:amount_cents], params[:currency])
    @invoice_id = params[:invoice_id]
    @invoice_url = params[:invoice_url]
    @billing_url = dashboard_billing_url(**localized_route_options)

    mail(to: @user.email, subject: t("billing_mailer.subscription_started.subject", app_name: app_name))
  end

  def subscription_upgraded
    @plan_name = params[:plan_name]
    @amount = formatted_amount(params[:amount_cents], params[:currency])
    @invoice_id = params[:invoice_id]
    @invoice_url = params[:invoice_url]
    @billing_url = dashboard_billing_url(**localized_route_options)

    mail(to: @user.email, subject: t("billing_mailer.subscription_upgraded.subject", app_name: app_name))
  end

  def one_time_purchase_confirmed
    @plan_names = Array(params[:plan_names]).map(&:to_s).reject(&:blank?)
    @amount = formatted_amount(params[:amount_cents], params[:currency])
    @charge_id = params[:charge_id]
    @receipt_url = params[:receipt_url]
    @marketplace_url = dashboard_marketplace_url(**localized_route_options)

    mail(to: @user.email, subject: t("billing_mailer.one_time_purchase_confirmed.subject", app_name: app_name))
  end

  def subscription_renewal_payment_failed
    @plan_name = params[:plan_name]
    @amount = formatted_amount(params[:amount_cents], params[:currency])
    @invoice_id = params[:invoice_id]
    @invoice_url = params[:invoice_url]
    @billing_url = dashboard_billing_url(**localized_route_options)

    mail(to: @user.email, subject: t("billing_mailer.subscription_renewal_payment_failed.subject", app_name: app_name))
  end

  private

  def assign_user
    @user = params[:user]
    raise ArgumentError, "user param is required" unless @user.is_a?(User)
  end

  def assign_branding
    @support_email = Rails.configuration.x.branding.support_email
  end

  def localized_route_options
    I18n.locale == I18n.default_locale ? {} : { locale: I18n.locale }
  end

  def formatted_amount(amount_cents, currency)
    Pay::Currency.format(amount_cents.to_i, currency: currency.to_s.presence || "usd")
  rescue StandardError
    ActiveSupport::NumberHelper.number_to_currency(amount_cents.to_f / 100.0)
  end

  def app_name
    Rails.configuration.x.branding.app_name
  end
end
