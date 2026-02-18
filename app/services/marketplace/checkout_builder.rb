module Marketplace
  class CheckoutBuilder
    Result = Struct.new(
      :allowed,
      :line_items,
      :metadata,
      :error_key,
      :error_options,
      keyword_init: true
    ) do
      def allowed?
        !!allowed
      end
    end

    def initialize(user:, entry:, base_plan_key:, addon_keys:, locale: I18n.locale)
      @user = user
      @entry = entry
      @base_plan_key = base_plan_key
      @addon_keys = normalize_keys(addon_keys)
      @locale = locale.presence || I18n.locale
    end

    def call
      return Result.new(allowed: false, error_key: "dashboard.marketplace.errors.checkout_unavailable") unless user && entry

      base_product = resolve_base_product
      base_plan = nil
      base_included = false
      selected_addons = []

      if base_product
        base_entry = Marketplace::Catalog.new(
          user: user,
          scope: MarketplaceProduct.where(id: base_product.id),
          include_eligibility: true
        ).call.first
        base_plan = base_entry&.plan
        return Result.new(allowed: false, error_key: "dashboard.marketplace.errors.base_missing") unless base_plan&.stripe_price_id

        manual_base_purchase = manual_purchase_exists?(base_plan)
        if manual_base_purchase && !entry.addon? && addon_keys.blank?
          return Result.new(allowed: false, error_key: "dashboard.marketplace.errors.already_purchased")
        end

        base_included = !base_entry.purchased && !manual_base_purchase

        addons = addons_for_base(base_entry)
        addon_map = addons.index_by { |addon| addon.billing_plan.key }
        selected_addons = addon_keys.filter_map { |key| addon_map[key] }

        purchased_plan_ids = purchased_or_manual_plan_ids(addons.pluck(:billing_plan_id))
        selected_addons.reject! { |addon| purchased_plan_ids.include?(addon.billing_plan_id) }

        unless base_included
          ineligible = selected_addons.find do |addon|
            eligibility = Addons::Eligibility.new(user: user, addon: addon).call
            !eligibility.allowed?
          end
          if ineligible
            base_label = addonable_label(ineligible.addonable) || I18n.t("dashboard.marketplace.errors.addon_base_default", locale: locale)
            return Result.new(
              allowed: false,
              error_key: "dashboard.marketplace.errors.addon_requires_base",
              error_options: { base: base_label }
            )
          end
        end
      elsif entry.addon?
        addon = entry.addon
        addon_plan = addon&.billing_plan
        return Result.new(allowed: false, error_key: "dashboard.marketplace.errors.base_missing") unless addon_plan&.stripe_price_id

        eligibility = Addons::Eligibility.new(user: user, addon: addon).call
        unless eligibility.allowed?
          base_label = addonable_label(eligibility.addonable) || I18n.t("dashboard.marketplace.errors.addon_base_default", locale: locale)
          return Result.new(
            allowed: false,
            error_key: "dashboard.marketplace.errors.addon_requires_base",
            error_options: { base: base_label }
          )
        end

        purchased_plan_ids = purchased_or_manual_plan_ids([addon_plan.id])
        return Result.new(allowed: false, error_key: "dashboard.marketplace.errors.already_purchased") if purchased_plan_ids.include?(addon_plan.id)

        selected_addons = [addon]
      else
        return Result.new(allowed: false, error_key: "dashboard.marketplace.errors.base_missing")
      end

      line_items = []
      plan_keys = []

      if base_included
        line_items << { price: base_plan.stripe_price_id, quantity: 1 }
        plan_keys << base_plan.key
      end

      selected_addons.each do |addon|
        plan = addon.billing_plan
        next unless plan&.stripe_price_id

        line_items << { price: plan.stripe_price_id, quantity: 1 }
        plan_keys << plan.key
      end

      return Result.new(allowed: false, error_key: "dashboard.marketplace.errors.no_items_selected") if line_items.empty?

      metadata = {
        "billing_plan_keys" => plan_keys.uniq.join(","),
        "marketplace_product_id" => entry.product.id.to_s,
        "marketplace_product_key" => entry.product.key
      }

      Result.new(allowed: true, line_items: line_items, metadata: metadata)
    end

    private

    attr_reader :user, :entry, :base_plan_key, :addon_keys, :locale

    def normalize_keys(keys)
      Array(keys)
        .flat_map { |value| value.to_s.split(",") }
        .map(&:strip)
        .reject(&:blank?)
        .uniq
    end

    def resolve_base_product
      if base_plan_key.present?
        product = find_base_by_plan_key
        return product if product && base_product_matches_entry?(product)

        return nil
      end

      return entry.product unless entry.addon?

      resolve_base_product_for_addon
    end

    def find_base_by_plan_key
      plan = BillingPlan.active.find_by(key: base_plan_key)
      return nil unless plan

      MarketplaceProduct.active.find_by(billing_plan_id: plan.id)
    end

    def base_product_matches_entry?(product)
      return true if entry.addon? && base_product_includes_addonable?(product, entry.addonable)
      return true if !entry.addon? && product == entry.product

      false
    end

    def resolve_base_product_for_addon
      addonable = entry.addonable
      return nil unless addonable

      scope = MarketplaceProduct.active.joins(:billing_plan).merge(BillingPlan.active)

      scope = case addonable
              when ExpertAdvisor
                scope.joins(billing_plan: :billing_plan_entitlements)
                     .where(billing_plan_entitlements: { expert_advisor_id: addonable.id })
              when Course
                scope.joins(billing_plan: :course_plan_entitlements)
                     .where(course_plan_entitlements: { course_id: addonable.id })
              when MarketplaceAsset
                scope.joins(billing_plan: :asset_plan_entitlements)
                     .where(asset_plan_entitlements: { marketplace_asset_id: addonable.id })
              else
                MarketplaceProduct.none
              end

      scope.left_joins(billing_plan: :addon).where(addons: { id: nil }).ordered.first
    end

    def base_product_includes_addonable?(product, addonable)
      return false unless product && addonable

      case addonable
      when ExpertAdvisor
        product.expert_advisors.exists?(addonable.id)
      when Course
        product.courses.exists?(addonable.id)
      when MarketplaceAsset
        product.marketplace_assets.exists?(addonable.id)
      else
        false
      end
    end

    def addons_for_base(base_entry)
      addonables = base_entry.expert_advisors + base_entry.courses + base_entry.marketplace_assets
      return [] if addonables.empty?

      Addon.where(addonable: addonables)
           .joins(:marketplace_product, :billing_plan)
           .merge(MarketplaceProduct.active)
           .merge(BillingPlan.active)
           .includes(:marketplace_product, :billing_plan)
    end

    def addonable_label(addonable)
      return nil unless addonable
      return addonable.name if addonable.is_a?(ExpertAdvisor)
      return addonable.title_for(locale) if addonable.respond_to?(:title_for)

      addonable.to_s
    end

    def manual_purchase_exists?(plan)
      return false unless user && plan

      ManualTransaction.where(user: user, billing_plan_id: plan.id).exists?
    end

    def purchased_or_manual_plan_ids(plan_ids)
      ids = Array(plan_ids).compact.uniq
      return [] if ids.empty?

      purchased_ids = MarketplacePurchase.where(user: user, billing_plan_id: ids).pluck(:billing_plan_id)
      manual_ids = ManualTransaction.where(user: user, billing_plan_id: ids).pluck(:billing_plan_id)
      purchased_ids | manual_ids
    end
  end
end
