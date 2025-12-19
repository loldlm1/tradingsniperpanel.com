Rails.configuration.to_prepare do
  Pay::Subscription.include Licenses::PaySubscriptionCallbacks

  Pay::Webhooks.configure do |events|
    # Ensure subscription lifecycle updates trigger Pay sync (and thus license sync via callbacks)
    events.subscribe "stripe.customer.subscription.created", Pay::Stripe::Webhooks::SubscriptionCreated.new
    events.subscribe "stripe.customer.subscription.updated", Pay::Stripe::Webhooks::SubscriptionUpdated.new
    events.subscribe "stripe.customer.subscription.deleted", Pay::Stripe::Webhooks::SubscriptionDeleted.new
    events.subscribe "stripe.invoice.upcoming", Pay::Stripe::Webhooks::SubscriptionRenewing.new
    events.subscribe "stripe.invoice.payment_failed", Pay::Stripe::Webhooks::PaymentFailed.new
  end
end
