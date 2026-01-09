module Licenses
  class SyncOneTimePurchaseJob < ApplicationJob
    queue_as :default

    retry_on StandardError, wait: 5.seconds, attempts: 3

    def perform(pay_charge_id)
      Licenses::OneTimePurchaseSync.new(pay_charge_id: pay_charge_id).call
    end
  end
end
