module Seeds
  module Runner
    module_function

    def seed_for_environment!(environment: Rails.env, allow_local: true)
      profile = Seeds::Profiles.current(environment: environment)

      case profile
      when Seeds::Profiles::PROD_MIRROR
        seed_prod_mirror!(allow_local: allow_local)
      when Seeds::Profiles::FULL_QA
        seed_full_qa!(allow_local: allow_local)
      else
        raise "Unsupported seed profile: #{profile.inspect}"
      end
    end

    def seed_prod_mirror!(allow_local: true)
      Seeds::BillingPlans.prune_for_profile!(profile: Seeds::Profiles::PROD_MIRROR)
      Seeds::ExpertAdvisors.prune_for_profile!(profile: Seeds::Profiles::PROD_MIRROR)

      Seeds::BillingPlans.seed_plans!(
        allow_local: allow_local,
        profile: Seeds::Profiles::PROD_MIRROR
      )

      core_records = Seeds::ExpertAdvisors.core_definitions(
        profile: Seeds::Profiles::PROD_MIRROR
      ).map do |attrs|
        bundle_path = core_bundle_paths(profile: Seeds::Profiles::PROD_MIRROR)[attrs[:ea_id]]
        Seeds::ExpertAdvisors.upsert_expert_advisor(attrs.dup, bundle_path: bundle_path)
      end

      Seeds::BillingPlans.seed_entitlements!
      Seeds::BillingPlans.prune_entitlements!(
        billing_plan_ids: BillingPlan.active.pluck(:id),
        expert_advisor_ids: ExpertAdvisor.active.pluck(:id)
      )
      core_records
    end

    def seed_full_qa!(allow_local: true)
      Seeds::BillingPlans.seed_plans!(
        allow_local: allow_local,
        profile: Seeds::Profiles::FULL_QA
      )

      core_records = Seeds::ExpertAdvisors.core_definitions(
        profile: Seeds::Profiles::FULL_QA
      ).map do |attrs|
        bundle_path = core_bundle_paths(profile: Seeds::Profiles::FULL_QA)[attrs[:ea_id]]
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

      { core_records: core_records, qa_records: qa_records }
    end

    def core_bundle_paths(profile:)
      paths = {
        "sniper_advanced_panel" => sniper_bundle_path
      }
      return paths if profile.to_s == Seeds::Profiles::PROD_MIRROR

      paths.merge("pandora_box" => pandora_bundle_path)
    end
    private_class_method :core_bundle_paths

    def sniper_bundle_path
      Rails.root.join("docs_eas", "sniper_advanced_panel", "sniper_advanced_panel_ea.zip")
    end
    private_class_method :sniper_bundle_path

    def pandora_bundle_path
      Rails.root.join("docs_eas", "pandora_box_ea", "pandora_box_ea.rar")
    end
    private_class_method :pandora_bundle_path

    def qa_bundle_path
      Rails.root.join("db", "seeds", "fixtures", "ea_bundle.rar")
    end
    private_class_method :qa_bundle_path
  end
end
