require "rails_helper"

RSpec.describe Discord::ReconcileVipRolesJob, type: :job do
  include ActiveJob::TestHelper

  before do
    clear_enqueued_jobs
    allow(Discord).to receive(:enabled?).and_return(true)
  end

  after do
    clear_enqueued_jobs
  end

  it "enqueues connected rows without issuing provider calls inline" do
    connected = create(:discord_connection, :connected)
    pending = create(:discord_connection, :connected, disconnect_requested_at: Time.current)
    create(:discord_connection)

    expect do
      described_class.perform_now
    end.to have_enqueued_job(Discord::SyncVipRoleJob).exactly(2).times

    expect(enqueued_jobs.map { |job| job.fetch(:args) }).to contain_exactly([ connected.id ], [ pending.id ])
  end

  it "exits while the integration is disabled" do
    create(:discord_connection, :connected)
    allow(Discord).to receive(:enabled?).and_return(false)

    described_class.perform_now

    expect(enqueued_jobs).to be_empty
  end

  it "preserves the daily license cron and adds hourly Discord reconciliation" do
    jobs = Rails.application.config.x.sidekiq_cron_jobs

    expect(jobs.fetch("licenses_expire_daily")).to eq(
      "cron" => "0 2 * * *",
      "class" => "Licenses::ExpireLicensesWorker",
      "queue" => "default"
    )
    expect(jobs.fetch("discord_vip_reconcile_hourly")).to include(
      "cron" => "15 * * * *",
      "class" => described_class.name,
      "active_job" => true
    )
  end
end
