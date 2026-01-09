Rails.configuration.to_prepare do
  if defined?(Pay::Charge)
    Pay::Charge.include Partners::PayChargeCallbacks
    Pay::Charge.include Billing::PayChargeCallbacks
  end
end
