sniper_bundle_path = Rails.root.join("docs_eas", "sniper_advanced_panel", "SniperAdvancedPanel.rar")
pandora_bundle_path = Rails.root.join("docs_eas", "pandora_box_ea", "pandora_box_ea.rar")
qa_bundle_path = Rails.root.join("db", "seeds", "fixtures", "ea_bundle.rar")

bundle_paths = {
  "sniper_advanced_panel" => sniper_bundle_path,
  "pandora_box" => pandora_bundle_path
}

Seeds::BillingPlans.seed_plans!(allow_local: true)

core_records = Seeds::ExpertAdvisors.core_definitions.map do |attrs|
  bundle_path = bundle_paths[attrs[:ea_id]]
  Seeds::ExpertAdvisors.upsert_expert_advisor(attrs.dup, bundle_path: bundle_path)
end

qa_records = Seeds::ExpertAdvisors.qa_definitions.map do |attrs|
  Seeds::ExpertAdvisors.upsert_expert_advisor(attrs.dup, bundle_path: qa_bundle_path)
end

Seeds::BillingPlans.seed_entitlements!
Seeds::Courses.seed_courses!
Seeds::MarketplaceAssets.seed_assets!
Seeds::MarketplaceProducts.seed_products!
Seeds::Addons.seed_addons!
Seeds::ExpertAdvisorBundles.seed_bundles!

qa_users = Seeds::QaUsers.seed!
qa_user = qa_users[:trader]
Seeds::MarketplacePurchases.seed_for(qa_user: qa_user)
Seeds::Courses.seed_progress_for(user: qa_user) if qa_user
Seeds::Partners.seed_qa!(partner: qa_users[:partner])
Seeds::Subscriptions.seed_manual_subscription_for(
  user: qa_user,
  recorded_by: qa_users[:partner] || qa_user
)
Seeds::DashboardMain.seed_for(user: qa_user, core_records: core_records, qa_records: qa_records)
Seeds::DashboardAnalytics.seed_for(user: qa_user)
Seeds::DashboardSamples.seed_activity_for(user: qa_user)
