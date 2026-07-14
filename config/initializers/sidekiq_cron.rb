cron_jobs = {
  "licenses_expire_daily" => {
    "cron" => "0 2 * * *",
    "class" => "Licenses::ExpireLicensesWorker",
    "queue" => "default"
  },
  "discord_vip_reconcile_hourly" => {
    "cron" => "15 * * * *",
    "class" => "Discord::ReconcileVipRolesJob",
    "queue" => "default",
    "active_job" => true
  }
}.freeze

Rails.application.config.x.sidekiq_cron_jobs = cron_jobs

if defined?(Sidekiq::Cron) && Sidekiq.server?
  Sidekiq::Cron::Job.load_from_hash(cron_jobs)
end
