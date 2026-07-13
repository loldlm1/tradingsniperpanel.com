module Admin
  module SubscriptionAudits
    class InvoiceSnapshot
      STATES = %w[succeeded refunded failed unpaid pending].freeze

      attr_reader :kind, :state, :processor_reference, :subscription_reference,
                  :amount_cents, :refunded_cents, :currency, :occurred_at,
                  :period_start, :period_end, :source

      def self.from_charge(charge, subscription_reference: nil)
        state = charge_state(charge)
        new(
          kind: "payment",
          state: state,
          processor_reference: charge.processor_id,
          subscription_reference: subscription_reference,
          amount_cents: charge.amount,
          refunded_cents: charge.amount_refunded.to_i,
          currency: charge.currency,
          occurred_at: charge.created_at,
          source: "pay_charge"
        )
      end

      def self.from_webhook(webhook)
        object = webhook.event.is_a?(Hash) ? webhook.event.dig("data", "object") : nil
        return unless object.is_a?(Hash)

        state = state_for(webhook.event_type, object["status"])

        new(
          kind: "invoice",
          state: state,
          processor_reference: object["id"],
          subscription_reference: reference_id(object["subscription"]),
          amount_cents: invoice_amount(object, state: state),
          refunded_cents: 0,
          currency: object["currency"],
          occurred_at: timestamp(webhook.event["created"] || object["created"]) || webhook.created_at,
          period_start: timestamp(object["period_start"]),
          period_end: timestamp(object["period_end"]),
          source: "pay_webhook"
        )
      end

      def self.customer_reference(webhook)
        object = webhook.event.is_a?(Hash) ? webhook.event.dig("data", "object") : nil
        return unless object.is_a?(Hash)

        reference_id(object["customer"])
      end

      def initialize(kind:, state:, processor_reference:, subscription_reference:, amount_cents:,
                     refunded_cents:, currency:, occurred_at:, source:, period_start: nil, period_end: nil)
        @kind = kind
        @state = STATES.include?(state) ? state : "pending"
        @processor_reference = processor_reference.to_s.presence
        @subscription_reference = subscription_reference.to_s.presence
        @amount_cents = integer_or_nil(amount_cents)
        @refunded_cents = integer_or_nil(refunded_cents) || 0
        @currency = currency.to_s.downcase.presence
        @occurred_at = occurred_at
        @period_start = period_start
        @period_end = period_end
        @source = source
      end

      def settled?
        state.in?(%w[succeeded refunded])
      end

      class << self
        private

        def state_for(event_type, invoice_status)
          return "failed" if event_type.to_s.in?(%w[invoice.payment_failed invoice.payment_action_required])
          return "succeeded" if event_type.to_s == "invoice.payment_succeeded" || invoice_status.to_s == "paid"
          return "unpaid" if event_type.to_s == "invoice.marked_uncollectible" || invoice_status.to_s.in?(%w[uncollectible void])

          "pending"
        end

        def charge_state(charge)
          return "refunded" if charge.refunded?

          status = charge.data["status"] if charge.data.is_a?(Hash)
          status = charge.object["status"] if status.blank? && charge.object.is_a?(Hash)
          return "succeeded" if status.blank? || status == "succeeded"
          return "failed" if status.in?(%w[failed canceled])
          return "unpaid" if status.in?(%w[unpaid uncollectible])

          "pending"
        end

        def invoice_amount(object, state:)
          if state.in?(%w[succeeded refunded])
            object["amount_paid"].presence || object["amount_due"].presence || object["amount_remaining"]
          else
            object["amount_due"].presence || object["amount_remaining"].presence || object["amount_paid"]
          end
        end

        def reference_id(value)
          value.is_a?(Hash) ? value["id"] : value
        end

        def timestamp(value)
          seconds = Integer(value, exception: false)
          Time.zone.at(seconds) if seconds
        end
      end

      private

      def integer_or_nil(value)
        Integer(value, exception: false)
      end
    end
  end
end
