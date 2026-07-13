namespace :catalog do
  namespace :pandora do
    desc "Verify the active Pandora-only catalog and renewal schedules"
    task verify: :environment do
      seed_root = Rails.root.join("db", "seeds")
      load(seed_root.join("profiles.rb")) unless defined?(Seeds::Profiles)
      load(seed_root.join("shared.rb")) unless defined?(Seeds::BillingPlans)

      Billing::PandoraCatalogReconciler.new.verify!
      puts "Pandora catalog verification passed."
    end
  end
end
