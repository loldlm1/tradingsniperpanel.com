class ApplicationMailer < ActionMailer::Base
  default from: ->(*) { self.class.email_from_address },
          reply_to: ->(*) { self.class.email_reply_to_address }
  layout "mailer"

  helper_method :app_name,
                :app_short_name,
                :email_display_name,
                :email_subject_brand,
                :support_email,
                :email_from_address,
                :email_reply_to_address,
                :mail_footer_copy,
                :mail_receiving_reason,
                :mail_signature

  def self.app_name
    Rails.configuration.x.branding.app_name
  end

  def self.app_short_name
    Rails.configuration.x.branding.short_name
  end

  def self.email_display_name
    Rails.configuration.x.branding.email_display_name
  end

  def self.email_subject_brand
    Rails.configuration.x.branding.email_subject_brand
  end

  def self.support_email
    Rails.configuration.x.branding.support_email
  end

  def self.email_from_address
    format_named_address(display_name: email_display_name, address: support_email)
  end

  def self.email_reply_to_address
    support_email
  end

  def app_name
    self.class.app_name
  end

  def app_short_name
    self.class.app_short_name
  end

  def email_display_name
    self.class.email_display_name
  end

  def email_subject_brand
    self.class.email_subject_brand
  end

  def support_email
    self.class.support_email
  end

  def email_from_address
    self.class.email_from_address
  end

  def email_reply_to_address
    self.class.email_reply_to_address
  end

  def mail_footer_copy
    I18n.t("mailers.shared.footer_copy", default: I18n.t("footer.tagline", default: app_name))
  end

  def mail_receiving_reason
    I18n.t("mailers.shared.receiving_notice", app_name: app_name)
  end

  def mail_signature
    I18n.t("mailers.shared.signature", app_name: app_name)
  end

  def default_preheader_text
    I18n.t("mailers.shared.default_preheader", app_name: app_name)
  end

  private

  def self.format_named_address(display_name:, address:)
    mail_address = Mail::Address.new(address)
    mail_address.display_name = display_name if display_name.present?
    mail_address.format
  end
  private_class_method :format_named_address
end
