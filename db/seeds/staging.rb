load Rails.root.join("db", "seeds", "production.rb")

Seeds::BillingPlans.seed_plans!
Seeds::ExpertAdvisors.core_definitions.each do |attrs|
  Seeds::ExpertAdvisors.upsert_expert_advisor(attrs.dup)
end
Seeds::BillingPlans.seed_entitlements!
Seeds::Courses.seed_courses!
Seeds::MarketplaceAssets.seed_assets!
Seeds::MarketplaceProducts.seed_products!
Seeds::Addons.seed_addons!
Seeds::ExpertAdvisorBundles.seed_bundles!
qa_users = Seeds::QaUsers.seed!
Seeds::Partners.seed_qa!(partner: qa_users[:partner])
