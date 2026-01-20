module Admin
  class MarketplaceProductUpsert
    Result = Struct.new(:product, :addon, :errors, keyword_init: true) do
      def ok?
        errors.blank?
      end
    end

    def initialize(
      product: nil,
      product_attributes: {},
      plan_attributes: {},
      entitlement_attributes: {},
      addon_attributes: {},
      logger: Rails.logger
    )
      @product = product
      @product_attributes = normalize_hash(product_attributes)
      @plan_attributes = normalize_hash(plan_attributes)
      @entitlement_attributes = normalize_hash(entitlement_attributes)
      @addon_attributes = normalize_hash(addon_attributes)
      @logger = logger
    end

    def call
      product = @product || MarketplaceProduct.new(product_attributes)
      addon_context = build_addon_context(product)

      if product.new_record? && plan_attributes[:amount_cents].nil?
        add_product_error!(product, I18n.t("active_admin.marketplace_products.errors.amount_missing"))
      end

      validate_addon_prereqs!(product, addon_context)

      MarketplaceProduct.transaction do
        product = upsert_product(product)
        sync_entitlements(product)
        addon = sync_addon(product, addon_context)
        Result.new(product: product, addon: addon, errors: [])
      end
    rescue ActiveRecord::RecordInvalid => e
      record = e.record
      errors = record&.errors&.full_messages
      errors = [e.message] if errors.blank?
      Result.new(product: product, addon: nil, errors: errors)
    rescue Stripe::StripeError, ArgumentError, KeyError => e
      logger.error(
        "[Admin::MarketplaceProductUpsert] failed marketplace_product_id=#{product&.id} slug=#{product&.slug}: #{e.class} - #{e.message}"
      )
      product.errors.add(:base, e.message) if product&.respond_to?(:errors)
      Result.new(product: product, addon: nil, errors: [e.message])
    end

    private

    attr_reader :product_attributes, :plan_attributes, :entitlement_attributes, :addon_attributes, :logger

    AddonContext = Struct.new(:addonable_type, :addonable_id, :addonable, :addon_key, keyword_init: true)

    def upsert_product(product)
      manager = Marketplace::ProductManager.new(logger: logger, stripe_required: true)
      if product.persisted?
        manager.update!(
          product: product,
          product_attributes: product_attributes,
          plan_attributes: plan_attributes
        )
      else
        manager.create!(
          product_attributes: product_attributes,
          plan_attributes: plan_attributes
        )
      end
    end

    def sync_entitlements(product)
      plan = product.billing_plan
      return unless plan

      sync_plan_entitlements(
        BillingPlanEntitlement,
        :expert_advisor_id,
        plan.id,
        entitlement_attributes[:expert_advisor_ids]
      )
      sync_plan_entitlements(
        CoursePlanEntitlement,
        :course_id,
        plan.id,
        entitlement_attributes[:course_ids]
      )
      sync_plan_entitlements(
        AssetPlanEntitlement,
        :marketplace_asset_id,
        plan.id,
        entitlement_attributes[:marketplace_asset_ids]
      )
    end

    def sync_addon(product, addon_context)
      plan = product.billing_plan
      return unless plan

      unless addon_context
        remove_addon(plan)
        return nil
      end

      addon = Addon.find_or_initialize_by(billing_plan: plan)
      addon.addonable = addon_context.addonable
      addon.key = resolved_addon_key(addon, addon_context, product)
      addon.save!

      update_plan_metadata(plan, addon)
      addon
    end

    def remove_addon(plan)
      addon = plan.addon
      return unless addon

      addon.destroy!
      update_plan_metadata(plan, nil)
    end

    def update_plan_metadata(plan, addon)
      metadata = (plan.metadata || {}).to_h
      if addon
        metadata["addon_key"] = addon.key
        metadata["addonable_type"] = addon.addonable_type
        metadata["addonable_id"] = addon.addonable_id
      else
        metadata.delete("addon_key")
        metadata.delete("addonable_type")
        metadata.delete("addonable_id")
      end
      plan.update!(metadata: metadata) if plan.metadata != metadata
    end

    def resolved_addon_key(addon, addon_context, product)
      addon_context.addon_key.presence || addon&.key || product.slug.to_s
    end

    def build_addon_context(product)
      addonable_type = addon_attributes[:addonable_type].to_s
      addonable_id = addon_attributes[:addonable_id].to_s
      addon_key = addon_attributes[:addon_key].to_s
      return nil if addonable_type.blank? || addonable_id.blank?

      unless Addon::ALLOWED_ADDONABLES.include?(addonable_type)
        add_product_error!(product, I18n.t("active_admin.marketplace_products.errors.addonable_missing"))
      end

      addonable_class = addonable_type.constantize
      addonable = addonable_class.find_by(id: addonable_id)
      unless addonable
        add_product_error!(product, I18n.t("active_admin.marketplace_products.errors.addonable_missing"))
      end

      AddonContext.new(
        addonable_type: addonable_type,
        addonable_id: addonable_id,
        addonable: addonable,
        addon_key: addon_key
      )
    rescue NameError
      add_product_error!(product, I18n.t("active_admin.marketplace_products.errors.addonable_missing"))
    end

    def validate_addon_prereqs!(product, addon_context)
      return unless addon_context

      addonable = addon_context.addonable
      if addonable.is_a?(MarketplaceAsset)
        unless marketplace_base_available?(product, addonable)
          add_product_error!(product, I18n.t("active_admin.marketplace_products.errors.asset_base_missing"))
        end
      end

      if addonable.is_a?(ExpertAdvisor)
        addon_key = addon_key_for_coverage(product, addon_context)
        coverage = ExpertAdvisors::BundleCoverage.new(
          expert_advisor: addonable,
          additional_addon_keys: [addon_key].compact
        ).call
        if coverage.missing_keys.any?
          add_product_error!(
            product,
            I18n.t("active_admin.marketplace_products.errors.bundle_missing", keys: coverage.missing_keys.join(", "))
          )
        end
      end
    end

    def addon_key_for_coverage(product, addon_context)
      return addon_context.addon_key if addon_context.addon_key.present?

      existing_key = product.billing_plan&.addon&.key
      return existing_key if existing_key.present?

      raw_slug = product.slug.presence || product_attributes[:slug].to_s
      raw_slug.to_s.parameterize(separator: "_").presence
    end

    def marketplace_base_available?(product, asset)
      plan_ids = asset.billing_plans.one_time.pluck(:id)
      plan_ids -= [product.billing_plan_id] if product&.billing_plan_id
      return false if plan_ids.empty?

      MarketplaceProduct.where(billing_plan_id: plan_ids).exists?
    end

    def sync_plan_entitlements(model, foreign_key, plan_id, subject_ids)
      desired_ids = normalize_ids(subject_ids)
      current_ids = model.where(billing_plan_id: plan_id).pluck(foreign_key)
      remove_ids = current_ids - desired_ids
      add_ids = desired_ids - current_ids

      if remove_ids.any?
        model.where(billing_plan_id: plan_id, foreign_key => remove_ids).delete_all
      end

      add_ids.each do |subject_id|
        model.create!(billing_plan_id: plan_id, foreign_key => subject_id)
      end
    end

    def add_product_error!(product, message)
      product.errors.add(:base, message)
      raise ActiveRecord::RecordInvalid, product
    end

    def normalize_hash(value)
      return {} if value.blank?

      value.to_h.symbolize_keys
    end

    def normalize_ids(value)
      Array(value).map(&:to_s).map(&:strip).reject(&:blank?).map(&:to_i).uniq
    end
  end
end
