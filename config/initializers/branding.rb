default_app_name = "Trading Sniper Panel"
default_short_name = "Sniper Panel"
default_support_email = "support@tradingsniperpanel.com"

app_name = ENV.fetch("APP_NAME", default_app_name).to_s.strip
app_name = default_app_name if app_name.blank?

short_name = ENV.fetch("APP_SHORT_NAME", "").to_s.strip
short_name = app_name if short_name.blank?

support_email = ENV.fetch("SUPPORT_EMAIL", default_support_email).to_s.strip
support_email = default_support_email if support_email.blank?

support_phone = ENV.fetch("SUPPORT_PHONE", "").to_s.strip
support_phone = nil if support_phone.blank?

support_chat_url = ENV.fetch("SUPPORT_CHAT_URL", "").to_s.strip
support_chat_url = nil if support_chat_url.blank?

support_discord_url = ENV.fetch("SUPPORT_DISCORD_URL", "").to_s.strip
support_discord_url = nil if support_discord_url.blank?

support_telegram_url = ENV.fetch("SUPPORT_TELEGRAM_URL", "").to_s.strip
support_telegram_url = nil if support_telegram_url.blank?

brand_legal_name = ENV.fetch("BRAND_LEGAL_NAME", "").to_s.strip
brand_legal_name = nil if brand_legal_name.blank?

brand_trade_name = ENV.fetch("BRAND_TRADE_NAME", "").to_s.strip
brand_trade_name = nil if brand_trade_name.blank?

brand_address_line1 = ENV.fetch("BRAND_ADDRESS_LINE1", "").to_s.strip
brand_address_line1 = nil if brand_address_line1.blank?

brand_address_line2 = ENV.fetch("BRAND_ADDRESS_LINE2", "").to_s.strip
brand_address_line2 = nil if brand_address_line2.blank?

brand_city = ENV.fetch("BRAND_CITY", "").to_s.strip
brand_city = nil if brand_city.blank?

brand_state = ENV.fetch("BRAND_STATE", "").to_s.strip
brand_state = nil if brand_state.blank?

brand_postal = ENV.fetch("BRAND_POSTAL", "").to_s.strip
brand_postal = nil if brand_postal.blank?

brand_country = ENV.fetch("BRAND_COUNTRY", "").to_s.strip
brand_country = nil if brand_country.blank?

Rails.configuration.x.branding = ActiveSupport::OrderedOptions.new
Rails.configuration.x.branding.app_name = app_name
Rails.configuration.x.branding.short_name = short_name
Rails.configuration.x.branding.support_email = support_email
Rails.configuration.x.branding.support_phone = support_phone
Rails.configuration.x.branding.support_chat_url = support_chat_url
Rails.configuration.x.branding.support_discord_url = support_discord_url
Rails.configuration.x.branding.support_telegram_url = support_telegram_url
Rails.configuration.x.branding.brand_legal_name = brand_legal_name
Rails.configuration.x.branding.brand_trade_name = brand_trade_name
Rails.configuration.x.branding.brand_address = {
  line1: brand_address_line1,
  line2: brand_address_line2,
  city: brand_city,
  state: brand_state,
  postal: brand_postal,
  country: brand_country
}
