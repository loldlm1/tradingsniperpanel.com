module Licenses
  class RegenerateKeysWorker
    include Sidekiq::Worker

    sidekiq_options queue: :default

    def perform
      Licenses::RegenerateKeys.new.call
    end
  end
end
