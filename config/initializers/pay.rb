Pay.setup do |config|
  config.enabled_processors = [:stripe]
  config.automount_routes = true

  config.application_name = "Trading Sniper Panel"
  config.business_name = "Trading Sniper"
  config.support_email = ENV.fetch("SUPPORT_EMAIL", "support@tradingsniperpanel.com")

  config.default_product_name = "sniper_advanced_panel"
  config.default_plan_name = "default"
end

Rails.application.config.to_prepare do
  if Pay::Stripe.private_key.present?
    require "stripe" unless defined?(Stripe)
    Stripe.api_key = Pay::Stripe.private_key
  else
    Rails.logger.error("Stripe secret key missing: set STRIPE_PRIVATE_KEY so Pay webhooks and jobs can authenticate")
  end
end
