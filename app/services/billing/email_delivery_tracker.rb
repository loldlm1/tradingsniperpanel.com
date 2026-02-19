module Billing
  class EmailDeliveryTracker
    UNIQUE_INDEX = :index_billing_email_deliveries_on_event_key

    def self.record_once(event_key:, event_type:, user_id: nil, pay_charge_id: nil, pay_subscription_id: nil, invoice_id: nil, metadata: {})
      now = Time.current
      result = BillingEmailDelivery.insert_all(
        [{
          event_key: event_key,
          event_type: event_type,
          user_id: user_id,
          pay_charge_id: pay_charge_id,
          pay_subscription_id: pay_subscription_id,
          invoice_id: invoice_id,
          metadata: metadata || {},
          delivered_at: now,
          created_at: now,
          updated_at: now
        }],
        unique_by: UNIQUE_INDEX
      )

      result.rows.any?
    end
  end
end
