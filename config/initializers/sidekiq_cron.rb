if defined?(Sidekiq::Cron) && Sidekiq.server?
  Sidekiq::Cron::Job.load_from_hash(
    "licenses_expire_daily" => {
      "cron" => "0 2 * * *",
      "class" => "Licenses::ExpireLicensesWorker",
      "queue" => "default"
    }
  )
end
