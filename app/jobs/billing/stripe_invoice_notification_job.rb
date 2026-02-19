module Billing
  class StripeInvoiceNotificationJob < ApplicationJob
    queue_as :default

    retry_on StandardError, wait: 10.seconds, attempts: 5

    def perform(event_payload)
      event = Stripe::Event.construct_from(event_payload.deep_stringify_keys)
      Billing::StripeInvoiceNotificationProcessor.new(event: event).call
    end
  end
end
