Rails.configuration.to_prepare do
  Pay::Subscription.include Licenses::PaySubscriptionCallbacks
end
