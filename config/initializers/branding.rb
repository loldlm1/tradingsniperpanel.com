default_app_name = "Trading Sniper Panel"
default_short_name = "Sniper Panel"
default_support_email = "support@tradingsniperpanel.com"

app_name = ENV.fetch("APP_NAME", default_app_name).to_s.strip
app_name = default_app_name if app_name.blank?

short_name = ENV.fetch("APP_SHORT_NAME", "").to_s.strip
short_name = app_name if short_name.blank?

support_email = ENV.fetch("SUPPORT_EMAIL", default_support_email).to_s.strip
support_email = default_support_email if support_email.blank?

Rails.configuration.x.branding = ActiveSupport::OrderedOptions.new
Rails.configuration.x.branding.app_name = app_name
Rails.configuration.x.branding.short_name = short_name
Rails.configuration.x.branding.support_email = support_email

I18n.backend.store_translations(:en, app: { name: app_name, short_name: short_name })
I18n.backend.store_translations(:es, app: { name: app_name, short_name: short_name })
