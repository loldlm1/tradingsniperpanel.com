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
      result = Billing::SubscriptionCatalogReconciler.new(
        allow_local: allow_local,
        profile: Seeds::Profiles::PROD_MIRROR
      ).call
      result.expert_advisors
    end

    def seed_full_qa!(allow_local: true)
      result = Billing::SubscriptionCatalogReconciler.new(
        allow_local: allow_local,
        profile: Seeds::Profiles::FULL_QA
      ).call
      core_records = result.expert_advisors
      qa_records = []

      Seeds::Courses.seed_courses!
      Seeds::MarketplaceAssets.seed_assets!

      qa_users = Seeds::QaUsers.seed!
      qa_user = qa_users[:trader]
      Seeds::Courses.seed_progress_for(user: qa_user) if qa_user
      Seeds::Partners.seed_qa!(partner: qa_users[:partner])
      Seeds::Partners.seed_eligible_qa!(partner: qa_users[:eligible_partner])
      Seeds::Subscriptions.seed_manual_subscription_for(
        user: qa_user,
        recorded_by: qa_users[:partner] || qa_user
      )
      Seeds::DashboardMain.seed_for(user: qa_user, core_records: core_records, qa_records: qa_records)
      Seeds::DashboardAnalytics.seed_for(user: qa_user)
      Seeds::DashboardSamples.seed_activity_for(user: qa_user)

      { core_records: core_records, qa_records: qa_records }
    end
  end
end
