module Billing
  class PandoraCatalogReconciler
    Result = Struct.new(:plans, :expert_advisor, :inventory, :migration, :retirement, keyword_init: true)

    def initialize(
      profile: Seeds::Profiles.current,
      allow_local: Rails.env.test?,
      logger: Rails.logger,
      migrator: nil,
      retirement_factory: nil
    )
      @profile = profile
      @allow_local = allow_local
      @logger = logger
      @migrator_provided = migrator.present?
      @migrator = migrator || Billing::LegacySubscriptionMigrator.new(logger: logger)
      @retirement_factory = retirement_factory || ->(desired_plans:, pandora_ea:, remote:) {
        Catalog::RetireLegacyAccess.new(
          desired_plans: desired_plans,
          pandora_ea: pandora_ea,
          remote: remote,
          logger: logger
        )
      }
    end

    def call
      plans = seed_desired_plans!
      pandora = seed_pandora!
      Seeds::BillingPlans.seed_entitlements!(profile: profile)
      verify_catalog!(plans:, pandora:, final: false)

      inventory = inventory_counts
      migration = migration_enabled? ? migrator.call : empty_migration_result
      retirement = retirement_factory.call(
        desired_plans: plans,
        pandora_ea: pandora,
        remote: remote?
      ).call
      verify_catalog!(plans: plans.map(&:reload), pandora: pandora.reload, final: true)
      migrator.verify! if migration_enabled?

      log_summary(plans:, inventory:, migration:, retirement:)
      Result.new(plans:, expert_advisor: pandora, inventory:, migration:, retirement:)
    end

    def verify!
      plans = BillingPlan.where(key: Billing::PandoraPricing::PLAN_KEYS).order(:key).to_a
      pandora = ExpertAdvisor.unscoped.find_by(ea_id: "pandora_box")
      verify_catalog!(plans:, pandora:, final: true)
      migrator.verify! if migration_enabled?
      true
    end

    private

    attr_reader :profile, :allow_local, :logger, :migrator, :retirement_factory, :migrator_provided

    def seed_desired_plans!
      Array(
        Seeds::BillingPlans.seed_plans!(
          allow_local: allow_local,
          profile: profile,
          retire_superseded_prices: false
        )
      )
    end

    def seed_pandora!
      attrs = Seeds::ExpertAdvisors.core_definitions(profile: profile).find { |definition| definition[:ea_id] == "pandora_box" }
      raise "Pandora Box EA seed definition is missing" unless attrs

      Seeds::ExpertAdvisors.upsert_expert_advisor(
        attrs.dup,
        bundle_path: Seeds::ExpertAdvisors.bundle_path_for("pandora_box")
      )
    end

    def verify_catalog!(plans:, pandora:, final:)
      plans_by_key = plans.index_by(&:key)
      unless plans_by_key.keys.sort == Billing::PandoraPricing::PLAN_KEYS.sort
        raise "Pandora catalog must contain both canonical plans"
      end
      raise "Pandora Box EA is missing" unless pandora

      Billing::PandoraPricing::PLAN_DEFINITIONS.each do |key, pricing|
        plan = plans_by_key.fetch(key)
        expected = {
          kind: "subscription",
          tier: Billing::PandoraPricing::TIER,
          interval: pricing.fetch(:interval),
          interval_count: pricing.fetch(:interval_count),
          amount_cents: pricing.fetch(:amount_cents),
          currency: Billing::PandoraPricing::CURRENCY,
          active: true
        }
        unless plan.attributes.symbolize_keys.slice(*expected.keys) == expected
          raise "Pandora plan #{key} does not match the desired catalog"
        end
        raise "Pandora plan #{key} is missing Stripe identifiers" if plan.stripe_product_id.blank? || plan.stripe_price_id.blank?

        history = plan.current_billing_plan_price
        unless history&.stripe_price_id == plan.stripe_price_id && history.active? && history.current?
          raise "Pandora plan #{key} is missing current price history"
        end
      end

      unless plans.map(&:stripe_product_id).uniq.one?
        raise "Pandora monthly and annual prices must share one Stripe product"
      end
      unless pandora.deleted_at.nil? && pandora.allowed_subscription_tiers == [ Billing::PandoraPricing::TIER ]
        raise "Pandora Box EA is not active for the canonical tier"
      end

      expected_entitlements = plans.map { |plan| [ plan.id, pandora.id ] }.sort
      actual_entitlements = BillingPlanEntitlement.where(billing_plan_id: plans.map(&:id)).pluck(:billing_plan_id, :expert_advisor_id).sort
      raise "Pandora entitlements are incomplete" unless actual_entitlements == expected_entitlements

      verify_remote_catalog!(plans) if remote?
      verify_final_state!(plans:, pandora:) if final
      true
    end

    def verify_remote_catalog!(plans)
      Stripe.api_key = ENV["STRIPE_PRIVATE_KEY"]
      product = Stripe::Product.retrieve(plans.first.stripe_product_id)
      raise "Pandora Stripe product is inactive" if value_for(product, :active) == false
      raise "Pandora Stripe product name is incorrect" unless value_for(product, :name).to_s == Billing::PandoraPricing::PRODUCT_NAME

      plans.each do |plan|
        price = Stripe::Price.retrieve(plan.stripe_price_id)
        recurring = value_for(price, :recurring)
        valid = value_for(price, :active) != false &&
                normalize_id(value_for(price, :product)) == plan.stripe_product_id &&
                value_for(price, :unit_amount).to_i == plan.amount_cents &&
                value_for(price, :currency).to_s.downcase == plan.currency &&
                value_for(recurring, :interval).to_s == plan.interval &&
                value_for(recurring, :interval_count).to_i == plan.interval_count
        raise "Pandora Stripe price #{plan.stripe_price_id} does not match the local catalog" unless valid
      end
    end

    def verify_final_state!(plans:, pandora:)
      active_plan_keys = BillingPlan.active.order(:key).pluck(:key)
      raise "Legacy billing plans remain active" unless active_plan_keys == Billing::PandoraPricing::PLAN_KEYS.sort

      active_ea_ids = ExpertAdvisor.unscoped.where(deleted_at: nil).order(:ea_id).pluck(:ea_id)
      raise "Legacy Expert Advisors remain active" unless active_ea_ids == [ pandora.ea_id ]
      raise "Marketplace products remain active" if MarketplaceProduct.active.exists?
      raise "Add-on plans remain active" if Addon.joins(:billing_plan).merge(BillingPlan.active).exists?
      raise "Legacy manual grants remain active" if ManualSubscription.active.joins(:billing_plan).where.not(billing_plans: { key: plans.map(&:key) }).exists?
      raise "One-time licenses remain active" if License.active_or_trial.where(access_source: "one_time").exists?
      raise "Role licenses remain active" if License.active_or_trial.where(source: Licenses::RevokeRoleAccess::ROLE_LICENSE_SOURCE).exists?
      raise "Non-Pandora licenses remain active" if License.active_or_trial.where.not(expert_advisor_id: pandora.id).exists?

      entitlements = BillingPlanEntitlement.pluck(:billing_plan_id, :expert_advisor_id).sort
      expected = plans.map { |plan| [ plan.id, pandora.id ] }.sort
      raise "Legacy entitlements remain active" unless entitlements == expected
    end

    def inventory_counts
      {
        stripe_subscriptions: Pay::Subscription.active.stripe.count,
        manual_grants: ManualSubscription.active.count,
        one_time_licenses: License.active_or_trial.where(access_source: "one_time").count,
        role_licenses: License.active_or_trial.where(source: Licenses::RevokeRoleAccess::ROLE_LICENSE_SOURCE).count
      }
    end

    def log_summary(plans:, inventory:, migration:, retirement:)
      logger.info(
        "[Billing::PandoraCatalogReconciler] complete " \
        "plans=#{plans.map(&:key).sort.join(',')} " \
        "subscriptions=#{inventory.fetch(:stripe_subscriptions)} " \
        "scheduled=#{migration.scheduled} verified=#{migration.verified} current=#{migration.current} " \
        "retired_plans=#{retirement.retired_plans} retired_prices=#{retirement.retired_prices} " \
        "revoked_licenses=#{retirement.revoked_licenses} expired_licenses=#{retirement.expired_licenses}"
      )
    end

    def remote?
      ENV["STRIPE_PRIVATE_KEY"].present? && !(allow_local && Rails.env.test?)
    end

    def migration_enabled?
      remote? || migrator_provided
    end

    def empty_migration_result
      Billing::LegacySubscriptionMigrator::Result.new(scheduled: 0, verified: 0, current: 0, canceling: 0)
    end

    def value_for(source, key)
      return if source.blank?
      return source.public_send(key) if source.respond_to?(key)
      return source[key] || source[key.to_s] if source.is_a?(Hash)

      nil
    end

    def normalize_id(value)
      return value if value.is_a?(String)
      return value.id if value.respond_to?(:id)

      value.to_s.presence
    end
  end
end
