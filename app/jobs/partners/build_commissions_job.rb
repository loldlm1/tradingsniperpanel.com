module Partners
  class BuildCommissionsJob < ApplicationJob
    queue_as :default

    def perform(pay_charge_id)
      Partners::CommissionBuilder.new(pay_charge_id: pay_charge_id).call
    end
  end
end
