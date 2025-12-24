namespace :licenses do
  desc "Enqueue regeneration of license keys to include unix expiry payloads"
  task regenerate_keys: :environment do
    Licenses::RegenerateKeysWorker.perform_async
  end
end
