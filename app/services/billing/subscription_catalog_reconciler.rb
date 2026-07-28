module Billing
  class SubscriptionCatalogReconciler
    Result = Struct.new(
      :plans,
      :expert_advisors,
      :expert_advisor,
      :inventory,
      :migration,
      :retirement,
      keyword_init: true
    )

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
      @retirement_factory = retirement_factory || lambda do |desired_plans:, desired_eas:, desired_entitlements:, remote:|
        Catalog::RetireLegacyAccess.new(
          desired_plans: desired_plans,
          desired_eas: desired_eas,
          desired_entitlements: desired_entitlements,
          remote: remote,
          logger: logger
        )
      end
    end

    def call
      plans = seed_desired_plans!
      expert_advisors = seed_expert_advisors!
      Seeds::BillingPlans.seed_entitlements!(profile: profile)
      entitlements = desired_entitlements(plans:, expert_advisors:)
      verify_catalog!(plans:, expert_advisors:, final: false)

      inventory = inventory_counts
      migration = migration_enabled? ? migrator.call : empty_migration_result
      retirement = retirement_factory.call(
        desired_plans: plans,
        desired_eas: expert_advisors,
        desired_entitlements: entitlements,
        remote: remote?
      ).call
      plans = plans.map(&:reload)
      expert_advisors = expert_advisors.map(&:reload)
      verify_catalog!(plans:, expert_advisors:, final: true)
      migrator.verify! if migration_enabled?

      log_summary(plans:, inventory:, migration:, retirement:)
      Result.new(
        plans: plans,
        expert_advisors: expert_advisors,
        expert_advisor: expert_advisors.find { |ea| ea.ea_id == "pandora_box" },
        inventory: inventory,
        migration: migration,
        retirement: retirement
      )
    end

    def verify!
      plans = BillingPlan.where(key: Billing::SubscriptionCatalog.plan_keys).order(:key).to_a
      expert_advisors = ExpertAdvisor.unscoped.where(ea_id: desired_ea_ids).order(:ea_id).to_a
      verify_catalog!(plans:, expert_advisors:, final: true)
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

    def seed_expert_advisors!
      definitions = Seeds::ExpertAdvisors.core_definitions(profile: profile).index_by { |definition| definition[:ea_id] }
      desired_ea_ids.map do |ea_id|
        attrs = definitions[ea_id]
        raise "#{ea_id} Expert Advisor seed definition is missing" unless attrs

        Seeds::ExpertAdvisors.upsert_expert_advisor(
          attrs.dup,
          bundle_path: Seeds::ExpertAdvisors.bundle_path_for(ea_id)
        )
      end
    end

    def verify_catalog!(plans:, expert_advisors:, final:)
      plans_by_key = plans.index_by(&:key)
      unless plans_by_key.keys.sort == Billing::SubscriptionCatalog.plan_keys.sort
        raise "Subscription catalog must contain all canonical plans"
      end

      eas_by_id = expert_advisors.index_by(&:ea_id)
      unless eas_by_id.keys.sort == desired_ea_ids.sort
        raise "Subscription catalog must contain all canonical Expert Advisors"
      end

      Billing::SubscriptionCatalog.products.each do |product|
        verify_product_plans!(product:, plans_by_key:)
      end
      verify_product_separation!(plans_by_key)
      verify_expert_advisors!(eas_by_id)
      verify_entitlements!(plans_by_key:, eas_by_id:, final:)
      verify_remote_catalog!(plans_by_key) if remote?
      verify_final_state!(plans_by_key:, eas_by_id:) if final
      true
    end

    def verify_product_plans!(product:, plans_by_key:)
      product.plan_definitions.each do |key, pricing|
        plan = plans_by_key.fetch(key)
        expected = {
          kind: "subscription",
          tier: product.tier,
          interval: pricing.fetch(:interval),
          interval_count: pricing.fetch(:interval_count),
          amount_cents: pricing.fetch(:amount_cents),
          currency: product.currency,
          active: true
        }
        unless plan.attributes.symbolize_keys.slice(*expected.keys) == expected
          raise "Subscription plan #{key} does not match the desired catalog"
        end
        if plan.stripe_product_id.blank? || plan.stripe_price_id.blank?
          raise "Subscription plan #{key} is missing Stripe identifiers"
        end

        history = plan.current_billing_plan_price
        unless history&.stripe_price_id == plan.stripe_price_id && history.active? && history.current?
          raise "Subscription plan #{key} is missing current price history"
        end
      end

      product_ids = product.plan_keys.map { |key| plans_by_key.fetch(key).stripe_product_id }.uniq
      raise "#{product.product_name} prices must share one Stripe product" unless product_ids.one?
    end

    def verify_product_separation!(plans_by_key)
      product_ids = Billing::SubscriptionCatalog.products.map do |product|
        plans_by_key.fetch(product.plan_keys.first).stripe_product_id
      end
      raise "Subscription products must use distinct Stripe products" unless product_ids.uniq.size == product_ids.size
    end

    def verify_expert_advisors!(eas_by_id)
      eas_by_id.each_value do |expert_advisor|
        expected_tiers = Billing::SubscriptionCatalog.products.filter_map do |product|
          product.tier if product.ea_ids.include?(expert_advisor.ea_id)
        end
        unless expert_advisor.deleted_at.nil? && expert_advisor.allowed_subscription_tiers == expected_tiers
          raise "#{expert_advisor.ea_id} is not active for the canonical tiers"
        end
      end
    end

    def verify_entitlements!(plans_by_key:, eas_by_id:, final:)
      expected = desired_entitlements(plans: plans_by_key.values, expert_advisors: eas_by_id.values)
                 .map { |plan, expert_advisor| [ plan.id, expert_advisor.id ] }
                 .sort
      actual = BillingPlanEntitlement.where(billing_plan_id: plans_by_key.values.map(&:id))
                                     .pluck(:billing_plan_id, :expert_advisor_id)
                                     .sort
      raise "Subscription entitlements are incomplete" if (expected - actual).any?
      raise "Legacy subscription entitlements remain" if final && actual != expected
    end

    def desired_entitlements(plans:, expert_advisors:)
      plans_by_key = Array(plans).index_by(&:key)
      eas_by_id = Array(expert_advisors).index_by(&:ea_id)

      Billing::SubscriptionCatalog.products.flat_map do |product|
        product.plan_keys.flat_map do |plan_key|
          product.ea_ids.map { |ea_id| [ plans_by_key.fetch(plan_key), eas_by_id.fetch(ea_id) ] }
        end
      end
    end

    def verify_remote_catalog!(plans_by_key)
      Stripe.api_key = ENV["STRIPE_PRIVATE_KEY"]

      Billing::SubscriptionCatalog.products.each do |product_definition|
        plans = product_definition.plan_keys.map { |key| plans_by_key.fetch(key) }
        product = Stripe::Product.retrieve(plans.first.stripe_product_id)
        raise "#{product_definition.product_name} Stripe product is inactive" if value_for(product, :active) == false
        unless value_for(product, :name).to_s == product_definition.product_name
          raise "#{product_definition.product_name} Stripe product name is incorrect"
        end

        plans.each do |plan|
          price = Stripe::Price.retrieve(plan.stripe_price_id)
          recurring = value_for(price, :recurring)
          valid = value_for(price, :active) != false &&
                  normalize_id(value_for(price, :product)) == plan.stripe_product_id &&
                  value_for(price, :unit_amount).to_i == plan.amount_cents &&
                  value_for(price, :currency).to_s.downcase == plan.currency &&
                  value_for(recurring, :interval).to_s == plan.interval &&
                  value_for(recurring, :interval_count).to_i == plan.interval_count
          raise "Stripe price #{plan.stripe_price_id} does not match the local catalog" unless valid
        end
      end
    end

    def verify_final_state!(plans_by_key:, eas_by_id:)
      active_plan_keys = BillingPlan.active.order(:key).pluck(:key)
      unless active_plan_keys == Billing::SubscriptionCatalog.plan_keys.sort
        raise "Legacy billing plans remain active"
      end

      active_ea_ids = ExpertAdvisor.unscoped.where(deleted_at: nil).order(:ea_id).pluck(:ea_id)
      raise "Legacy Expert Advisors remain active" unless active_ea_ids == desired_ea_ids.sort
      raise "Marketplace products remain active" if MarketplaceProduct.active.exists?
      raise "Add-on plans remain active" if Addon.joins(:billing_plan).merge(BillingPlan.active).exists?
      if ManualSubscription.active.joins(:billing_plan).where.not(billing_plans: { key: plans_by_key.keys }).exists?
        raise "Legacy manual grants remain active"
      end
      raise "One-time licenses remain active" if License.active_or_trial.where(access_source: "one_time").exists?
      if License.active_or_trial.where(source: Licenses::RevokeRoleAccess::ROLE_LICENSE_SOURCE).exists?
        raise "Role licenses remain active"
      end
      if License.active_or_trial.where.not(expert_advisor_id: eas_by_id.values.map(&:id)).exists?
        raise "Non-catalog licenses remain active"
      end

      entitlements = BillingPlanEntitlement.pluck(:billing_plan_id, :expert_advisor_id).sort
      expected = desired_entitlements(plans: plans_by_key.values, expert_advisors: eas_by_id.values)
                 .map { |plan, expert_advisor| [ plan.id, expert_advisor.id ] }
                 .sort
      raise "Legacy entitlements remain active" unless entitlements == expected
    end

    def desired_ea_ids
      @desired_ea_ids ||= Billing::SubscriptionCatalog.products.flat_map(&:ea_ids).uniq
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
        "[Billing::SubscriptionCatalogReconciler] complete " \
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
