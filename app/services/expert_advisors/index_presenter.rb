require "set"

module ExpertAdvisors
  class IndexPresenter
    include Rails.application.routes.url_helpers

    AddonItem = Struct.new(:title, :owned, :purchase_url, keyword_init: true)
    Card = Struct.new(
      :index,
      :entry,
      :expert_advisor,
      :status_label,
      :status_class,
      :type_label,
      :meta_tags,
      :guide_copy,
      :guide_cta_label,
      :guide_url,
      :details_url,
      :download_url,
      :download_enabled,
      :addons_total_count,
      :addons_owned_count,
      :addons_progress_percent,
      :addon_items,
      :license_display,
      :license_hint,
      :license_copy_text,
      :license_copy_enabled,
      :tag_list,
      :search_text,
      :visible_by_default,
      keyword_init: true
    )

    def initialize(entries:, user:, locale: I18n.locale, marketplace_available: false, page: nil, items: 8)
      @entries = Array(entries)
      @user = user
      @locale = locale.presence || I18n.locale
      @marketplace_available = marketplace_available
      @items = items
      @page = page.to_i
      @page = 1 if @page < 1
      @offset = (@page - 1) * @items

      preload_context
    end

    attr_reader :entries, :items, :page

    def cards
      @cards ||= entries.map.with_index { |entry, index| build_card(entry, index) }
    end

    def pagy
      @pagy ||= Pagy::Offset.new(count: entries.size, page: page, limit: items)
    end

    def tag_filters
      @tag_filters ||= top_tags_for(entries)
    end

    def total_count
      entries.size
    end

    def default_url_options
      { locale: @locale }
    end

    private

    attr_reader :user, :locale, :marketplace_available, :offset

    def preload_context
      @addons_by_ea_id = load_addons
      @purchased_plan_ids = load_purchased_plan_ids
      @marketplace_products_by_ea_id = load_marketplace_products
    end

    def load_addons
      ea_ids = entries.map { |entry| entry.expert_advisor.id }
      return Hash.new { |hash, key| hash[key] = [] } if ea_ids.empty?

      addons = Addon.where(addonable_type: "ExpertAdvisor", addonable_id: ea_ids)
                    .includes(:billing_plan, :marketplace_product)
                    .left_joins(billing_plan: :marketplace_product)
                    .order(Arel.sql("marketplace_products.sort_order ASC NULLS LAST, marketplace_products.title_en ASC NULLS LAST"))

      addons.group_by(&:addonable_id)
    end

    def load_purchased_plan_ids
      return Set.new if user.blank?

      plan_ids = @addons_by_ea_id.values.flatten.map(&:billing_plan_id).compact.uniq
      return Set.new if plan_ids.empty?

      MarketplacePurchase.where(user: user, billing_plan_id: plan_ids).pluck(:billing_plan_id).to_set
    end

    def load_marketplace_products
      ea_ids = entries.map { |entry| entry.expert_advisor.id }
      return {} if ea_ids.empty?

      products = MarketplaceProduct.active
                                   .joins(billing_plan: :billing_plan_entitlements)
                                   .where(billing_plan_entitlements: { expert_advisor_id: ea_ids })
                                   .includes(billing_plan: :expert_advisors)
                                   .order(:sort_order)

      products.each_with_object({}) do |product, map|
        product.expert_advisors.each do |expert_advisor|
          map[expert_advisor.id] ||= product
        end
      end
    end

    def build_card(entry, index)
      expert_advisor = entry.expert_advisor
      status = entry.status || :locked
      addon_items = addon_items_for(expert_advisor)

      Card.new(
        index: index,
        entry: entry,
        expert_advisor: expert_advisor,
        status_label: status_label(status),
        status_class: status_badge_class(status),
        type_label: type_label_for(expert_advisor),
        meta_tags: display_tags(expert_advisor.tag_list),
        guide_copy: guide_copy_for(expert_advisor),
        guide_cta_label: guide_cta_label_for(entry),
        guide_url: guide_url_for(entry, expert_advisor),
        details_url: dashboard_expert_advisor_path(expert_advisor, locale: locale),
        download_url: download_url_for(entry, expert_advisor),
        download_enabled: download_enabled?(entry, expert_advisor),
        addons_total_count: addon_items.size,
        addons_owned_count: addon_items.count(&:owned),
        addons_progress_percent: addons_progress_percent(addon_items),
        addon_items: addon_items,
        license_display: license_display_for(entry),
        license_hint: license_hint_for(entry),
        license_copy_text: entry.accessible ? entry.license_key : nil,
        license_copy_enabled: entry.accessible && entry.license_key.present?,
        tag_list: normalized_tags(expert_advisor.tag_list),
        search_text: build_search_text(expert_advisor),
        visible_by_default: visible_by_default?(index)
      )
    end

    def status_label(status)
      I18n.t("dashboard.expert_advisors.status.#{status}", default: status.to_s.humanize)
    end

    def status_badge_class(status)
      case status.to_s
      when "active"
        "bg-emerald-100 text-emerald-700 dark:bg-emerald-500/20 dark:text-emerald-200"
      when "trial"
        "bg-amber-100 text-amber-700 dark:bg-amber-500/20 dark:text-amber-200"
      else
        "bg-gray-100 text-gray-700 dark:bg-gray-700/60 dark:text-gray-100"
      end
    end

    def type_label_for(expert_advisor)
      I18n.t("dashboard.expert_advisors.types.#{expert_advisor.ea_type}", default: expert_advisor.ea_type.to_s.humanize)
    end

    def display_tags(tags)
      Array(tags).map { |tag| tag.to_s.strip }.reject(&:blank?).first(3)
    end

    def guide_copy_for(_expert_advisor)
      I18n.t("dashboard.expert_advisors.index.guide_copy")
    end

    def guide_cta_label_for(entry)
      key = entry.accessible ? "dashboard.expert_advisors.guide_cta" : "dashboard.expert_advisors.unlock_cta"
      I18n.t(key)
    end

    def guide_url_for(entry, expert_advisor)
      return dashboard_expert_advisor_guides_path(expert_advisor, locale: locale) if entry.accessible

      unlock_url_for(entry, expert_advisor)
    end

    def download_url_for(entry, expert_advisor)
      return nil unless download_enabled?(entry, expert_advisor)

      dashboard_expert_advisor_download_path(expert_advisor, locale: locale)
    end

    def download_enabled?(entry, expert_advisor)
      entry.accessible && download_available?(expert_advisor)
    end

    def download_available?(expert_advisor)
      expert_advisor.ea_files.attached? || expert_advisor.expert_advisor_bundles.any?
    end

    def unlock_url_for(entry, expert_advisor)
      if marketplace_available
        product = @marketplace_products_by_ea_id[expert_advisor.id]
        return dashboard_marketplace_product_path(product, locale: locale) if product.present?
      end

      cta_key = cta_key_for(entry)
      return dashboard_plans_path(locale: locale) if cta_key.blank?

      dashboard_plans_path(locale: locale, price_key: cta_key)
    end

    def cta_key_for(entry)
      tier = entry.allowed_tiers.first
      return nil if tier.blank?

      plan = BillingPlan.subscription.active.where(tier: tier).order(:sort_order).first
      plan&.key || "#{tier}_monthly"
    end

    def addon_items_for(expert_advisor)
      addons = Array(@addons_by_ea_id[expert_advisor.id])
      return [] if addons.empty?

      owned, unowned = addons.partition { |addon| @purchased_plan_ids.include?(addon.billing_plan_id) }
      ordered = unowned + owned

      ordered.first(3).map do |addon|
        AddonItem.new(
          title: addon_title(addon),
          owned: @purchased_plan_ids.include?(addon.billing_plan_id),
          purchase_url: addon_purchase_url(addon)
        )
      end
    end

    def addon_title(addon)
      product = addon.marketplace_product
      product ? product.title_for(locale) : addon.key
    end

    def addon_purchase_url(addon)
      return nil unless marketplace_available

      product = addon.marketplace_product
      return nil if product.blank?

      dashboard_marketplace_product_path(product, locale: locale)
    end

    def addons_progress_percent(addon_items)
      total = addon_items.size
      return 0 if total.zero?

      owned = addon_items.count(&:owned)
      ((owned.to_f / total) * 100).round
    end

    def license_display_for(entry)
      return entry.license_key if entry.accessible && entry.license_key.present?

      I18n.t("dashboard.expert_advisors.license.locked_value")
    end

    def license_hint_for(entry)
      return I18n.t("dashboard.expert_advisors.license.hint") if entry.accessible && entry.license_key.present?

      I18n.t("dashboard.expert_advisors.license.locked_hint")
    end

    def normalized_tags(tags)
      Array(tags).map { |tag| tag.to_s.strip }.reject(&:blank?).map(&:downcase)
    end

    def build_search_text(expert_advisor)
      addon_titles = addon_titles_for_search(expert_advisor)
      parts = [
        expert_advisor.name,
        expert_advisor.description,
        type_label_for(expert_advisor),
        *normalized_tags(expert_advisor.tag_list),
        *addon_titles
      ].compact

      parts.join(" ").downcase
    end

    def addon_titles_for_search(expert_advisor)
      addons = Array(@addons_by_ea_id[expert_advisor.id])
      addons.map { |addon| addon_title(addon) }.compact
    end

    def visible_by_default?(index)
      return true if items.to_i <= 0

      index >= offset && index < (offset + items)
    end

    def top_tags_for(entries)
      ea_ids = entries.map { |entry| entry.expert_advisor.id }
      return [] if ea_ids.empty?

      ActsAsTaggableOn::Tag.joins(:taggings)
                           .where(taggings: { taggable_type: "ExpertAdvisor", taggable_id: ea_ids, context: "tags" })
                           .group("tags.id")
                           .order(Arel.sql("COUNT(taggings.id) DESC"), "tags.name ASC")
                           .limit(5)
                           .pluck("tags.name")
    end
  end
end
