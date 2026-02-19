require_relative "production"

Rails.application.configure do
  # Staging is reachable over HTTP in current infra.
  config.assume_ssl = false
  config.force_ssl = false

  # Never send real emails from regular staging requests/jobs.
  config.action_mailer.delivery_method = :test
  config.action_mailer.perform_deliveries = false
  config.action_mailer.raise_delivery_errors = false
end
