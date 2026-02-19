Pay.setup do |config|
  config.enabled_processors = [:stripe]
  config.automount_routes = true

  config.application_name = Rails.configuration.x.branding.app_name
  config.business_name = Rails.configuration.x.branding.app_name
  config.support_email = Rails.configuration.x.branding.support_email
  # Use app-specific transactional templates instead of Pay defaults.
  config.send_emails = false

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
