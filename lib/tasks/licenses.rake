namespace :licenses do
  desc "Backfill Chu subscription licenses for active Pandora subscribers"
  task backfill_chu_subscription_licenses: :environment do
    dry_run = ActiveModel::Type::Boolean.new.cast(ENV.fetch("DRY_RUN", "true"))
    batch_size = Integer(ENV.fetch("BATCH_SIZE", Licenses::BackfillChuSubscriptionLicenses::DEFAULT_BATCH_SIZE.to_s))
    user_ids = ENV["USER_IDS"]&.split(",")&.map(&:strip)&.reject(&:blank?)

    result = Licenses::BackfillChuSubscriptionLicenses.new(
      dry_run: dry_run,
      batch_size: batch_size,
      user_ids: user_ids
    ).call

    result.summary.each do |key, value|
      puts "#{key}=#{value.is_a?(Array) ? value.join(',') : value}"
    end
    abort "Chu license backfill completed with failures" if result.failed?
  rescue ArgumentError => e
    abort "Invalid backfill options: #{e.message}"
  end
end
