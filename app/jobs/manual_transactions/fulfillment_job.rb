module ManualTransactions
  class FulfillmentJob < ApplicationJob
    queue_as :default

    retry_on StandardError, wait: 5.seconds, attempts: 3

    def perform(manual_transaction_id)
      ManualTransactions::Fulfillment.new(manual_transaction_id: manual_transaction_id).call
    end
  end
end
