module Licenses
  class RegenerateKeysWorker
    include Sidekiq::Worker

    sidekiq_options queue: :default

    def perform
      Rails.logger.warn("[Licenses::RegenerateKeysWorker] retired without rotating license tokens")
    end
  end
end
