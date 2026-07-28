namespace :discord do
  namespace :vip do
    CLEANUP_CONFIRMATION = "REMOVE LINKED PANDORA VIP".freeze

    desc "Audit local subscription Discord VIP eligibility and synchronization state"
    task audit: :environment do
      rows = DiscordConnection.connected.includes(:user).to_a
      eligibility = rows.map { |connection| Discord::VipEligibility.new(user: connection.user).call }

      puts "connections=#{rows.size}"
      puts "eligible=#{eligibility.count(&:eligible?)}"
      puts "ineligible=#{eligibility.count { |result| !result.eligible? }}"
      puts "failed=#{rows.count { |connection| connection.sync_status == 'failed' }}"
      puts "membership_pending=#{rows.count { |connection| connection.membership_pending == true }}"
    end

    desc "Enqueue hourly-style reconciliation for linked Discord accounts"
    task reconcile: :environment do
      if Discord.enabled?
        Discord::ReconcileVipRolesJob.perform_later
        puts "reconciliation_enqueued=1"
      else
        puts "reconciliation_enqueued=0 reason=disabled"
      end
    end

    desc "Remove subscription VIP from linked Discord accounts after exact confirmation"
    task cleanup_linked_roles: :environment do
      unless ENV["CONFIRM"] == CLEANUP_CONFIRMATION
        abort "Refusing cleanup. Set CONFIRM='#{CLEANUP_CONFIRMATION}' exactly."
      end

      Discord.configuration.validate!
      client = Discord::Client.new
      removed = 0
      failed = 0

      DiscordConnection.connected.find_each do |connection|
        client.remove_vip_role(user_id: connection.discord_user_id)
        connection.update!(
          vip_role_state: "removed",
          sync_status: "idle",
          sync_started_at: nil,
          last_synced_at: Time.current,
          last_error_code: nil,
          last_error_at: nil
        )
        removed += 1
      rescue Discord::Error => e
        connection.update_columns(
          sync_status: "failed",
          sync_started_at: nil,
          last_error_code: e.code,
          last_error_at: Time.current,
          updated_at: Time.current
        )
        failed += 1
      end

      puts "removed=#{removed} failed=#{failed}"
      abort "Discord VIP cleanup completed with failures" if failed.positive?
    end
  end
end
