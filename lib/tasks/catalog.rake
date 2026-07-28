namespace :catalog do
  namespace :subscriptions do
    desc "Verify the active multi-product subscription catalog and renewal schedules"
    task verify: :environment do
      seed_root = Rails.root.join("db", "seeds")
      load(seed_root.join("profiles.rb")) unless defined?(Seeds::Profiles)
      load(seed_root.join("shared.rb")) unless defined?(Seeds::BillingPlans)

      Billing::SubscriptionCatalogReconciler.new.verify!
      puts "Subscription catalog verification passed."
    end
  end

  namespace :pandora do
    desc "Compatibility alias for catalog:subscriptions:verify"
    task verify: :environment do
      Rake::Task["catalog:subscriptions:verify"].invoke
    end
  end
end
