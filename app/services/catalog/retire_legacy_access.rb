module Catalog
  class RetireLegacyAccess
    Result = Struct.new(
      :retired_plans,
      :retired_prices,
      :retired_remote_prices,
      :retired_remote_products,
      :retired_marketplace_products,
      :retired_addons,
      :retired_expert_advisors,
      :removed_entitlements,
      :cancelled_manual_grants,
      :revoked_licenses,
      :expired_licenses,
      keyword_init: true
    )

    def initialize(
      desired_plans:,
      desired_eas: nil,
      desired_entitlements: nil,
      pandora_ea: nil,
      remote:,
      logger: Rails.logger,
      now: Time.current
    )
      @desired_plans = Array(desired_plans)
      @desired_eas = Array(desired_eas.presence || pandora_ea).compact
      @desired_entitlements = desired_entitlements
      @remote = remote
      @logger = logger
      @now = now
      raise ArgumentError, "desired plans are required" if @desired_plans.empty?
      raise ArgumentError, "desired Expert Advisors are required" if @desired_eas.empty?
    end

    def call
      remote_counts = remote ? retire_remote_catalog! : { prices: 0, products: 0 }
      local_counts = retire_local_catalog!

      Result.new(
        retired_remote_prices: remote_counts.fetch(:prices),
        retired_remote_products: remote_counts.fetch(:products),
        **local_counts
      )
    end

    private

    attr_reader :desired_plans, :desired_eas, :desired_entitlements, :remote, :logger, :now

    def desired_plan_ids
      @desired_plan_ids ||= desired_plans.map(&:id)
    end

    def desired_plan_keys
      @desired_plan_keys ||= desired_plans.map(&:key)
    end

    def desired_ea_ids
      @desired_ea_ids ||= desired_eas.map(&:id)
    end

    def desired_entitlement_pairs
      @desired_entitlement_pairs ||= begin
        pairs = desired_entitlements || desired_plans.product(desired_eas)
        Array(pairs).map do |plan, expert_advisor|
          [ plan.respond_to?(:id) ? plan.id : plan, expert_advisor.respond_to?(:id) ? expert_advisor.id : expert_advisor ]
        end.uniq.sort
      end
    end

    def desired_price_ids
      @desired_price_ids ||= desired_plans.map(&:stripe_price_id)
    end

    def desired_product_ids
      @desired_product_ids ||= desired_plans.map(&:stripe_product_id).uniq
    end

    def retire_remote_catalog!
      raise ArgumentError, "STRIPE_PRIVATE_KEY is required for remote catalog retirement" if ENV["STRIPE_PRIVATE_KEY"].blank?

      Stripe.api_key = ENV["STRIPE_PRIVATE_KEY"]
      price_ids = retired_remote_price_ids
      product_ids = retired_remote_product_ids
      price_ids.each { |price_id| deactivate_remote_price(price_id) }
      product_ids.each { |product_id| deactivate_remote_product(product_id) }
      { prices: price_ids.size, products: product_ids.size }
    end

    def retired_remote_price_ids
      history_ids = BillingPlanPrice.active.where.not(stripe_price_id: desired_price_ids).pluck(:stripe_price_id)
      canonical_ids = BillingPlan.where.not(key: desired_plan_keys).where.not(stripe_price_id: [ nil, "" ]).pluck(:stripe_price_id)
      (history_ids + canonical_ids).compact_blank.uniq.sort
    end

    def retired_remote_product_ids
      BillingPlan.where.not(stripe_product_id: [ nil, "" ])
                 .where.not(stripe_product_id: desired_product_ids)
                 .distinct
                 .pluck(:stripe_product_id)
                 .sort
    end

    def deactivate_remote_price(price_id)
      price = Stripe::Price.retrieve(price_id)
      return if price.blank? || value_for(price, :active) == false

      Stripe::Price.update(price_id, active: false)
    rescue Stripe::InvalidRequestError => e
      raise unless missing_resource_error?(e)

      logger.warn("[Catalog::RetireLegacyAccess] missing Stripe price price_id=#{price_id}; treating as retired")
    end

    def deactivate_remote_product(product_id)
      product = Stripe::Product.retrieve(product_id)
      return if product.blank? || value_for(product, :active) == false

      Stripe::Product.update(product_id, active: false)
    rescue Stripe::InvalidRequestError => e
      raise unless missing_resource_error?(e)

      logger.warn("[Catalog::RetireLegacyAccess] missing Stripe product product_id=#{product_id}; treating as retired")
    end

    def retire_local_catalog!
      BillingPlan.transaction do
        stale_plan_ids = BillingPlan.where.not(key: desired_plan_keys).pluck(:id)
        active_stale_plan_ids = BillingPlan.where(id: stale_plan_ids, active: true).pluck(:id)
        marketplace_count = MarketplaceProduct.where(status: "active").update_all(status: "draft", updated_at: now)
        addon_count = Addon.where(billing_plan_id: active_stale_plan_ids).count
        manual_count = cancel_legacy_manual_grants(stale_plan_ids)
        entitlement_count = remove_legacy_entitlements
        expert_advisor_count = ExpertAdvisor.unscoped.where.not(id: desired_ea_ids).where(deleted_at: nil).update_all(
          deleted_at: now,
          updated_at: now
        )
        plan_count = BillingPlan.where(id: stale_plan_ids, active: true).update_all(active: false, updated_at: now)
        price_count = retire_local_price_history
        license_counts = retire_licenses

        {
          retired_plans: plan_count,
          retired_prices: price_count,
          retired_marketplace_products: marketplace_count,
          retired_addons: addon_count,
          retired_expert_advisors: expert_advisor_count,
          removed_entitlements: entitlement_count,
          cancelled_manual_grants: manual_count,
          revoked_licenses: license_counts.fetch(:revoked),
          expired_licenses: license_counts.fetch(:expired)
        }
      end
    end

    def cancel_legacy_manual_grants(stale_plan_ids)
      return 0 if stale_plan_ids.empty?

      ManualSubscription.where(billing_plan_id: stale_plan_ids)
                        .where.not(status: [ ManualSubscription::STATUSES[:cancelled], ManualSubscription::STATUSES[:superseded] ])
                        .where("ends_at > ?", now)
                        .update_all(status: ManualSubscription::STATUSES[:cancelled], updated_at: now)
    end

    def remove_legacy_entitlements
      stale_ids = BillingPlanEntitlement.pluck(:id, :billing_plan_id, :expert_advisor_id).filter_map do |id, plan_id, expert_advisor_id|
        id unless desired_entitlement_pairs.include?([ plan_id, expert_advisor_id ])
      end
      BillingPlanEntitlement.where(id: stale_ids).delete_all
    end

    def retire_local_price_history
      count = 0
      BillingPlanPrice.where.not(stripe_price_id: desired_price_ids).where("active = TRUE OR current = TRUE").find_each do |history|
        history.update_columns(
          active: false,
          current: false,
          retired_at: history.retired_at || now,
          updated_at: now
        )
        count += 1
      end
      count
    end

    def retire_licenses
      revoked = 0
      expired = 0
      revoke_scope.reorder(:id).lock.each do |license|
        license.update!(status: "revoked", trial_ends_at: nil, expires_at: now, last_synced_at: now)
        revoked += 1
      end

      License.active_or_trial.where.not(expert_advisor_id: desired_ea_ids).reorder(:id).lock.each do |license|
        license.update!(status: "expired", trial_ends_at: nil, expires_at: now, last_synced_at: now)
        expired += 1
      end
      { revoked: revoked, expired: expired }
    end

    def revoke_scope
      one_time = License.active_or_trial.where(access_source: "one_time")
      role = License.active_or_trial.where(source: Licenses::RevokeRoleAccess::ROLE_LICENSE_SOURCE)
      one_time.or(role)
    end

    def value_for(source, key)
      return if source.blank?
      return source.public_send(key) if source.respond_to?(key)
      return source[key] || source[key.to_s] if source.is_a?(Hash)

      nil
    end

    def missing_resource_error?(error)
      return true if error.respond_to?(:code) && error.code.to_s == "resource_missing"

      error.message.to_s.downcase.include?("no such")
    end
  end
end
