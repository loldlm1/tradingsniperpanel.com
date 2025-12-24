module Licenses
  class ExpireLicensesWorker
    include Sidekiq::Worker

    sidekiq_options queue: :default

    def perform
      Licenses::ExpireLicenses.new.call
    end
  end
end
