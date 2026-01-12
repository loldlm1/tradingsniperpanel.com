return unless defined?(ExpertAdvisor)

load Rails.root.join("db", "seeds", "production.rb")

Seeds::BillingPlans.seed_plans!
Seeds::BillingPlans.seed_entitlements!
Seeds::Courses.seed_courses!
Seeds::Marketplace.seed_products!
qa_users = Seeds::QaUsers.seed!
Seeds::Partners.seed_qa!(partner: qa_users[:partner])
