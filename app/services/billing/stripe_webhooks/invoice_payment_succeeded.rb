module Billing
  module StripeWebhooks
    class InvoicePaymentSucceeded
      def call(event)
        Billing::StripeInvoiceNotificationJob.perform_later(event.to_hash)
      end
    end
  end
end
