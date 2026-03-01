module Marketplace
  class ShowPresenter
    include Rails.application.routes.url_helpers

    AddonRow = Struct.new(
      :addon,
      :product,
      :title,
      :price_display,
      :price_cents,
      :plan_key,
      :selected,
      keyword_init: true
    )

    RelatedItem = Struct.new(
      :product,
      :title,
      :summary,
      :image,
      :price_display,
      :detail_url,
      keyword_init: true
    )

    RELATED_LIMIT = 3
    DEFAULT_PLACEHOLDER = "mosaic/images/applications-image-09.jpg"

    def initialize(user:, entry:, locale: I18n.locale)
      @user = user
      @entry = entry
      @locale = locale.presence || I18n.locale
    end

    def call
      @product = entry.product
      @base_entry = resolve_base_entry
      @base_product = base_entry&.product || product
      @addon_rows = build_addon_rows
      @related_items = build_related_items
      self
    end

    attr_reader :entry, :product, :base_entry, :base_product, :addon_rows, :related_items

    def title
      product.title_for(locale)
    end

    def summary
      product.summary_for(locale).presence || product.description_for(locale)
    end

    def description
      product.description_for(locale).presence || summary
    end

    def online_seat_feature
      return nil unless entry.plan&.one_time?
      return nil if entry.expert_advisors.empty?

      Licenses::OnlineSeatCopy.one_time_feature(locale: locale)
    end

    def tags
      entry.tags
    end

    def image
      image_for(product)
    end

    def base_price_display
      price_display_for(base_entry&.plan)
    end

    def base_price_cents
      base_entry&.plan&.amount_cents.to_i
    end

    def base_plan_key
      base_entry&.plan&.key
    end

    def base_required?
      base_entry.present? && !base_entry.purchased
    end

    def checkout_base_available?
      return true if base_entry.present?
      return addon_checkout_allowed_without_base_product? if entry.addon?

      false
    end

    def base_owned?
      base_entry.present? && base_entry.purchased
    end

    def required_base_label
      return base_product&.title_for(locale) || product.title_for(locale) if base_entry.present?
      return addonable_label(entry.addonable) || I18n.t("dashboard.marketplace.errors.addon_base_default", locale: locale) if entry.addon?

      base_product&.title_for(locale) || product.title_for(locale)
    end

    def add_on_progress
      total = addon_rows.size
      selected = addon_rows.count(&:selected)
      {
        total: total,
        selected: selected,
        percent: total.positive? ? ((selected.to_f / total) * 100).round : 0
      }
    end

    def addon_total_cents
      addon_rows.select(&:selected).sum(&:price_cents)
    end

    def addon_total_display
      format_price(addon_total_cents)
    end

    def cart_total_cents
      (base_required? ? base_price_cents : 0) + addon_total_cents
    end

    def cart_total_display
      format_price(cart_total_cents)
    end

    def selected_addon_keys
      addon_rows.select(&:selected).map(&:plan_key)
    end

    def related_load_more_url
      params = {}
      tab = tab_for_entry(entry)
      params[:tab] = tab if tab.present?
      tag = normalized_tags(entry.tags).first
      params[:tags] = [tag] if tag.present?
      dashboard_marketplace_path(locale: locale, **params)
    end

    def show_promo_badge?
      false
    end

    def show_ratings?
      false
    end

    def show_legal?
      false
    end

    def default_url_options
      { locale: locale }
    end

    private

    attr_reader :user, :locale

    def resolve_base_entry
      return entry unless entry.addon?

      base_product = resolve_base_product(entry)
      return nil unless base_product

      Marketplace::Catalog.new(
        user: user,
        scope: MarketplaceProduct.where(id: base_product.id),
        include_eligibility: true
      ).call.first
    end

    def resolve_base_product(entry)
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

      scope = scope.left_joins(billing_plan: :addon).where(addons: { id: nil })
      scope.ordered.first
    end

    def build_addon_rows
      base = base_entry
      return fallback_addon_rows_for_entry_addon unless base

      addonables = base.expert_advisors + base.courses + base.marketplace_assets
      return [] if addonables.empty?

      addons = Addon.where(addonable: addonables)
                    .joins(:marketplace_product, :billing_plan)
                    .merge(MarketplaceProduct.active)
                    .merge(BillingPlan.active)
                    .includes(:marketplace_product, :billing_plan)
                    .order("marketplace_products.sort_order ASC, marketplace_products.title_en ASC")

      owned_plan_ids = owned_plan_ids_for(addons.map(&:billing_plan_id))

      preselected_keys = []
      if entry.addon? && entry.plan&.key.present? && !owned_plan_ids.include?(entry.plan.id)
        preselected_keys << entry.plan.key
      end

      addons.each_with_object([]) do |addon, rows|
        next if owned_plan_ids.include?(addon.billing_plan_id)

        plan = addon.billing_plan
        product = addon.marketplace_product
        rows << AddonRow.new(
          addon: addon,
          product: product,
          title: product&.title_for(locale) || addon.key,
          price_display: price_display_for(plan),
          price_cents: plan&.amount_cents.to_i,
          plan_key: plan&.key,
          selected: preselected_keys.include?(plan&.key)
        )
      end
    end

    def fallback_addon_rows_for_entry_addon
      return [] unless entry.addon?

      addon = entry.addon
      plan = addon&.billing_plan
      product = addon&.marketplace_product || entry.product
      return [] unless addon && plan && product

      owned_plan_ids = owned_plan_ids_for([plan.id])
      return [] if owned_plan_ids.include?(plan.id)

      [
        AddonRow.new(
          addon: addon,
          product: product,
          title: product.title_for(locale),
          price_display: price_display_for(plan),
          price_cents: plan.amount_cents.to_i,
          plan_key: plan.key,
          selected: true
        )
      ]
    end

    def owned_plan_ids_for(plan_ids)
      ids = Array(plan_ids).compact.uniq
      return [] if ids.empty?
      return ids if Access::PrivilegedRolePolicy.full_access?(user)

      purchased_ids = MarketplacePurchase.where(user: user, billing_plan_id: ids).pluck(:billing_plan_id)
      manual_ids = ManualTransaction.where(user: user, billing_plan_id: ids).pluck(:billing_plan_id)
      purchased_ids | manual_ids
    end

    def addon_checkout_allowed_without_base_product?
      @addon_checkout_allowed_without_base_product ||= begin
        return false unless entry.addon?

        if !entry.eligible.nil?
          entry.eligible
        else
          Addons::Eligibility.new(user: user, addon: entry.addon).call.allowed?
        end
      end
    end

    def addonable_label(addonable)
      return nil unless addonable
      return addonable.name if addonable.is_a?(ExpertAdvisor)
      return addonable.title_for(locale) if addonable.respond_to?(:title_for)

      addonable.to_s
    end

    def build_related_items
      candidates = Marketplace::Catalog.new(user: user).call
      candidates.reject! { |item| item.product == product || item.purchased }

      current_type = entry_type(entry)
      current_tags = normalized_tags(entry.tags)

      ranked = candidates.map do |candidate|
        type_match = entry_type(candidate) == current_type ? 1 : 0
        tag_overlap = (current_tags & normalized_tags(candidate.tags)).size
        score = (type_match * 10) + tag_overlap
        next if score.zero?

        [candidate, score]
      end.compact

      ranked.sort_by { |(candidate, score)| [-score, candidate.product.sort_order.to_i, candidate.product.title_en.to_s] }
            .first(RELATED_LIMIT)
            .map do |candidate, _score|
              RelatedItem.new(
                product: candidate.product,
                title: candidate.product.title_for(locale),
                summary: candidate.product.summary_for(locale).presence || candidate.product.description_for(locale),
                image: image_for(candidate.product),
                price_display: candidate.price_display || price_display_for(candidate.plan),
                detail_url: dashboard_marketplace_product_path(candidate.product)
              )
            end
    end

    def normalized_tags(tags)
      Array(tags).map { |tag| tag.to_s.strip.downcase }.reject(&:blank?).uniq
    end

    def entry_type(entry)
      return :addons if entry.addon?

      course_count = entry.courses.size
      ea_count = entry.expert_advisors.size
      asset_count = entry.marketplace_assets.size
      type_count = [course_count.positive?, ea_count.positive?, asset_count.positive?].count(true)
      item_count = course_count + ea_count + asset_count

      return :bundles if type_count > 1 || item_count > 1
      return :courses if course_count.positive?
      return :expert_advisors if ea_count.positive?
      return :marketplace_assets if asset_count.positive?

      :other
    end

    def tab_for_entry(entry)
      type = entry_type(entry)
      return if type == :other

      type
    end

    def image_for(product)
      return product.image if product.image.attached?

      DEFAULT_PLACEHOLDER
    end

    def price_display_for(plan)
      return nil unless plan&.amount_cents

      format_price(plan.amount_cents)
    end

    def format_price(cents)
      ActionController::Base.helpers.number_to_currency(cents.to_f / 100, unit: "$", precision: 2)
    end
  end
end
