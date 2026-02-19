module Marketplace
  class IndexPresenter
    include Rails.application.routes.url_helpers

    TAG_LIMIT = 8
    PAGE_SIZE = 8
    TRENDING_LIMIT = 4
    TRENDING_WINDOW_DAYS = 30
    POPULAR_PURCHASE_THRESHOLD = 5
    DEFAULT_PLACEHOLDER = "mosaic/images/applications-image-09.jpg"

    CATEGORY_PLACEHOLDERS = %w[
      mosaic/images/shop-category-01.png
      mosaic/images/shop-category-02.png
      mosaic/images/shop-category-03.png
      mosaic/images/shop-category-04.png
    ].freeze

    TAB_CONFIG = {
      all: "dashboard.marketplace.tabs.all",
      featured: "dashboard.marketplace.tabs.featured",
      courses: "dashboard.marketplace.tabs.courses",
      expert_advisors: "dashboard.marketplace.tabs.expert_advisors",
      marketplace_assets: "dashboard.marketplace.tabs.marketplace_assets",
      addons: "dashboard.marketplace.tabs.addons",
      bundles: "dashboard.marketplace.tabs.bundles"
    }.freeze

    TAB_ORDER = %i[all featured courses expert_advisors marketplace_assets addons bundles].freeze

    TYPE_TERMS = {
      addons: %w[addon addons add-on add-ons],
      bundles: %w[bundle bundles]
    }.freeze

    CourseCard = Struct.new(
      :product,
      :title,
      :image,
      :rating,
      :price_display,
      :duration_seconds,
      :lessons_count,
      :modules_count,
      :category,
      :cta_label_key,
      :detail_url,
      keyword_init: true
    )

    DigitalGoodCard = Struct.new(
      :product,
      :title,
      :summary,
      :image,
      :rating,
      :rating_count,
      :price_display,
      :cta_label_key,
      :detail_url,
      :popular,
      keyword_init: true
    )

    CategoryCard = Struct.new(
      :title,
      :image,
      :cta_label_key,
      :cta_url,
      keyword_init: true
    )

    TrendingCard = Struct.new(
      :title,
      :image,
      :cta_label_key,
      :cta_url,
      keyword_init: true
    )

    attr_reader :query, :selected_tags, :selected_tab
    attr_reader :course_cards, :digital_goods_cards, :category_cards, :trending_cards

    def initialize(user:, params:, locale: I18n.locale)
      @user = user
      @params = params
      @locale = locale.presence || I18n.locale
    end

    def call
      @query = @params[:q].to_s.strip
      @selected_tags = normalized_tags(@params[:tags])
      @selected_tab = normalized_tab(@params[:tab])

      @course_cards = show_courses? ? build_course_cards : []
      @digital_goods_cards = show_digital_goods? ? build_digital_goods_cards : []
      @category_cards = show_categories? ? build_category_cards : []
      @trending_cards = show_trending? ? build_trending_cards : []

      self
    end

    def tabs
      available_tab_keys.map { |key| { key: key, label_key: TAB_CONFIG.fetch(key) } }
    end

    def course_section_label_key
      "dashboard.marketplace.sections.courses"
    end

    def digital_goods_section_label_key
      case selected_tab
      when :expert_advisors then "dashboard.marketplace.sections.expert_advisors"
      when :marketplace_assets then "dashboard.marketplace.sections.marketplace_assets"
      when :addons then "dashboard.marketplace.sections.addons"
      when :bundles then "dashboard.marketplace.sections.bundles"
      else "dashboard.marketplace.sections.digital_goods"
      end
    end

    def filtering?
      query.present? || selected_tags.any?
    end

    def page_size
      PAGE_SIZE
    end

    def course_pages
      pages_for(course_cards)
    end

    def digital_goods_pages
      pages_for(digital_goods_cards)
    end

    def empty_state?
      return course_cards.empty? && digital_goods_cards.empty? if selected_tab == :all

      entries_for_tab(filtered_entries, selected_tab).empty?
    end

    def show_courses?
      selected_tab.in?([:all, :featured, :courses])
    end

    def show_digital_goods?
      selected_tab != :courses
    end

    def show_categories?
      selected_tab == :all && !empty_state?
    end

    def show_online_events?
      false
    end

    def show_trending?
      selected_tab == :all && !empty_state?
    end

    def tags
      entries = entries_for_tagging
      counts = tag_counts(entries)
      ordered = counts.sort_by { |(name, count)| [-count, name] }.map(&:first)
      (ordered.first(TAG_LIMIT) + selected_tags).uniq
    end

    def params_for_tab(tab_key)
      params = base_params
      if tab_key == :all
        params.delete(:tab)
      else
        params[:tab] = tab_key.to_s
      end
      params
    end

    def params_for_tag(tag)
      params = base_params
      next_tags = selected_tags.include?(tag) ? (selected_tags - [tag]) : (selected_tags + [tag])
      if next_tags.any?
        params[:tags] = next_tags
      else
        params.delete(:tags)
      end
      params
    end

    def clear_tags_params
      params = base_params
      params.delete(:tags)
      params
    end

    def default_url_options
      { locale: @locale }
    end

    private

    attr_reader :user, :locale

    def normalized_tab(value)
      return :all if value.blank?

      normalized = value.to_s
      return :featured if normalized == "featured"
      return :courses if normalized == "courses"
      return :expert_advisors if normalized == "expert_advisors"
      return :marketplace_assets if normalized == "marketplace_assets"
      return :addons if normalized == "addons"
      return :bundles if normalized == "bundles"

      :all
    end

    def normalized_tags(value)
      tags =
        case value
        when ActionController::Parameters, Hash
          value.keys
        else
          Array(value)
        end

      tags.map(&:to_s).map(&:strip).reject(&:blank?).map(&:downcase).uniq
    end

    def base_params
      params = {}
      params[:q] = query if query.present?
      params[:tab] = selected_tab.to_s if selected_tab.present? && selected_tab != :all
      params[:tags] = selected_tags if selected_tags.any?
      params
    end

    def search_terms
      @search_terms ||= query.to_s.downcase.split(/\s+/).map(&:strip).reject(&:blank?)
    end

    def text_search_terms
      @text_search_terms ||= search_terms - TYPE_TERMS.values.flatten
    end

    def type_filters
      @type_filters ||= TYPE_TERMS.each_with_object([]) do |(type, terms), filters|
        filters << type if (search_terms & terms).any?
      end
    end

    def search_scope
      terms = text_search_terms
      scope = MarketplaceProduct.all
      return scope if terms.empty?

      scope = scope.left_joins(
        :billing_plan,
        billing_plan: [:addon, :expert_advisors, :courses, :marketplace_assets]
      )

      product_table = MarketplaceProduct.arel_table
      plan_table = BillingPlan.arel_table
      addon_table = Addon.arel_table
      ea_table = ExpertAdvisor.arel_table
      course_table = Course.arel_table
      asset_table = MarketplaceAsset.arel_table

      conditions = terms.map do |term|
        pattern = "%#{ActiveRecord::Base.sanitize_sql_like(term)}%"
        condition = product_table[:title_en].matches(pattern)
          .or(product_table[:title_es].matches(pattern))
          .or(product_table[:summary_en].matches(pattern))
          .or(product_table[:summary_es].matches(pattern))
          .or(product_table[:description_en].matches(pattern))
          .or(product_table[:description_es].matches(pattern))
          .or(product_table[:slug].matches(pattern))
          .or(product_table[:key].matches(pattern))
          .or(plan_table[:name].matches(pattern))
          .or(plan_table[:key].matches(pattern))
          .or(addon_table[:key].matches(pattern))
          .or(ea_table[:name].matches(pattern))
          .or(course_table[:title_en].matches(pattern))
          .or(course_table[:title_es].matches(pattern))
          .or(course_table[:category].matches(pattern))
          .or(asset_table[:title_en].matches(pattern))
          .or(asset_table[:title_es].matches(pattern))
        ea_type_condition = ea_type_condition_for(term, ea_table)
        condition = condition.or(ea_type_condition) if ea_type_condition
        condition
      end

      combined = conditions.reduce { |memo, condition| memo.or(condition) }
      scope.where(combined).distinct
    end

    def ea_type_condition_for(term, ea_table)
      normalized = term.to_s.tr("-", "_")
      return unless ExpertAdvisor.ea_types.key?(normalized)

      ea_table[:ea_type].eq(ExpertAdvisor.ea_types.fetch(normalized))
    end

    def base_entries
      @base_entries ||= begin
        entries = Marketplace::Catalog.new(user: user, scope: search_scope).call
        entries.reject!(&:purchased)
        entries = filter_entries_by_query_type(entries)
        entries
      end
    end

    def filter_entries_by_query_type(entries)
      return entries if type_filters.empty?

      entries.select { |entry| type_filters.include?(entry_type(entry)) }
    end

    def filtered_entries
      @filtered_entries ||= begin
        entries = base_entries
        entries = filter_entries_by_tags(entries)
        entries = entries_for_tab(entries, selected_tab) if selected_tab != :all
        entries
      end
    end

    def entries_for_tagging
      entries = base_entries
      entries = entries_for_tab(entries, selected_tab) if selected_tab != :all
      entries
    end

    def filter_entries_by_tags(entries)
      return entries if selected_tags.empty?

      entries.select do |entry|
        entry_tags = entry.tags.map(&:downcase)
        (entry_tags & selected_tags).any?
      end
    end

    def entries_for_tab(entries, tab_key)
      return entries if tab_key == :all
      return featured_entries(entries) if tab_key == :featured

      entries.select { |entry| entry_type(entry) == tab_key }
    end

    def available_tab_keys
      types = base_entries.map { |entry| entry_type(entry) }.uniq
      ordered = TAB_ORDER.select do |key|
        key == :all || (key == :featured && base_entries.any?) || types.include?(key)
      end
      ordered << selected_tab if selected_tab != :all && !ordered.include?(selected_tab)
      ordered
    end

    def featured_entries(entries)
      return [] if entries.empty?

      purchase_counts = purchase_counts_for(entries)
      usage_counts = usage_counts_for(entries)
      sorted = sorted_entries(entries, purchase_counts, usage_counts)
      prioritized = sorted.select do |entry|
        plan_id = entry.plan&.id
        purchase_counts[plan_id].to_i.positive? || usage_counts[plan_id].to_i.positive?
      end

      prioritized.presence || sorted
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

    def tag_counts(entries)
      entries.each_with_object(Hash.new(0)) do |entry, counts|
        entry.tags.each do |tag|
          normalized = tag.to_s.downcase
          next if normalized.blank?

          counts[normalized] += 1
        end
      end
    end

    def course_entries(entries)
      entries.select { |entry| entry_type(entry) == :courses }
    end

    def digital_goods_entries(entries)
      entries.reject { |entry| entry_type(entry) == :courses }
    end

    def build_course_cards
      entries = course_entries(filtered_entries)
      return [] if entries.empty?

      purchase_counts = purchase_counts_for(entries)
      usage_counts = usage_counts_for(entries)
      metric_counts = metric_counts_for(entries, purchase_counts, usage_counts)
      max_metric = metric_counts.values.max.to_f

      course_ids = entries.flat_map { |entry| entry.courses.map(&:id) }.uniq
      module_counts = CourseModule.where(course_id: course_ids).group(:course_id).count
      lesson_counts = CourseLesson.joins(:course_module)
                                  .where(course_modules: { course_id: course_ids })
                                  .group("course_modules.course_id")
                                  .count
      duration_sums = CourseLesson.joins(:course_module)
                                  .where(course_modules: { course_id: course_ids })
                                  .group("course_modules.course_id")
                                  .sum(:duration_seconds)

      sorted_entries(entries, purchase_counts, usage_counts).map do |entry|
        product = entry.product
        plan_id = entry.plan&.id
        course_ids = entry.courses.map(&:id)
        CourseCard.new(
          product: product,
          title: product.title_for(locale),
          image: image_for(product),
          rating: rating_from_metric(metric_counts[plan_id].to_f, max_metric),
          price_display: entry.price_display || price_display_for(entry.plan),
          duration_seconds: course_ids.sum { |id| duration_sums[id].to_i },
          lessons_count: course_ids.sum { |id| lesson_counts[id].to_i },
          modules_count: course_ids.sum { |id| module_counts[id].to_i },
          category: entry.courses.first&.category,
          cta_label_key: "dashboard.marketplace.cta.buy_now",
          detail_url: dashboard_marketplace_product_path(product)
        )
      end
    end

    def build_digital_goods_cards
      entries = digital_goods_entries(filtered_entries)
      return [] if entries.empty?

      purchase_counts = purchase_counts_for(entries)
      usage_counts = usage_counts_for(entries)
      metric_counts = metric_counts_for(entries, purchase_counts, usage_counts)
      max_metric = metric_counts.values.max.to_f

      sorted_entries(entries, purchase_counts, usage_counts).map.with_index do |entry, index|
        product = entry.product
        plan_id = entry.plan&.id
        summary = product.summary_for(locale).presence || product.description_for(locale)
        purchase_count = purchase_counts[plan_id].to_i
        metric_count = metric_counts[plan_id].to_i

        DigitalGoodCard.new(
          product: product,
          title: product.title_for(locale),
          summary: summary,
          image: image_for(product),
          rating: rating_from_metric(metric_count.to_f, max_metric),
          rating_count: metric_count,
          price_display: entry.price_display || price_display_for(entry.plan),
          cta_label_key: "dashboard.marketplace.cta.buy_now",
          detail_url: dashboard_marketplace_product_path(product),
          popular: index.zero? && purchase_count >= POPULAR_PURCHASE_THRESHOLD
        )
      end
    end

    def build_category_cards
      entries = base_entries
      return [] if entries.empty?

      cards = []

      if entries.any? { |entry| entry.expert_advisors.any? || entry.addonable.is_a?(ExpertAdvisor) }
        cards << CategoryCard.new(
          title: I18n.t("dashboard.marketplace.categories.expert_advisors", locale: locale),
          image: CATEGORY_PLACEHOLDERS[0],
          cta_label_key: "dashboard.marketplace.cta.explore",
          cta_url: dashboard_marketplace_path(tab: :expert_advisors)
        )
      end

      if entries.any? { |entry| entry.expert_advisors.any? { |ea| ea.ea_type == "ea_tool" } || entry.addonable&.ea_type == "ea_tool" }
        cards << CategoryCard.new(
          title: I18n.t("dashboard.marketplace.categories.tools", locale: locale),
          image: CATEGORY_PLACEHOLDERS[1],
          cta_label_key: "dashboard.marketplace.cta.explore",
          cta_url: dashboard_marketplace_path(tab: :expert_advisors, q: "ea_tool")
        )
      end

      top_category = top_course_category(entries)
      if top_category.present?
        category_label = I18n.t("dashboard.courses.categories.#{top_category}", locale: locale, default: top_category.to_s.humanize)
        cards << CategoryCard.new(
          title: category_label,
          image: CATEGORY_PLACEHOLDERS[2],
          cta_label_key: "dashboard.marketplace.cta.explore",
          cta_url: dashboard_marketplace_path(tab: :courses, q: top_category)
        )
      end

      if entries.any? { |entry| entry_type(entry).in?(%i[addons bundles]) }
        cards << CategoryCard.new(
          title: I18n.t("dashboard.marketplace.categories.addons_bundles", locale: locale),
          image: CATEGORY_PLACEHOLDERS[3],
          cta_label_key: "dashboard.marketplace.cta.explore",
          cta_url: dashboard_marketplace_path(q: "addon bundle")
        )
      end

      cards
    end

    def top_course_category(entries)
      course_ids = entries.flat_map { |entry| entry.courses.map(&:id) }.uniq
      return nil if course_ids.empty?

      category = CourseEnrollment.joins(:course)
                                 .where(course_id: course_ids)
                                 .group("courses.category")
                                 .order(Arel.sql("COUNT(course_enrollments.id) DESC"))
                                 .limit(1)
                                 .pluck("courses.category")
                                 .first
      return category if category.present?

      Course.where(id: course_ids).where.not(category: [nil, ""]).order(:category).limit(1).pluck(:category).first
    end

    def build_trending_cards
      entries = filter_entries_by_tags(base_entries)
      return [] if entries.empty?

      purchase_counts = purchase_counts_for(entries, window_days: TRENDING_WINDOW_DAYS)
      sorted_by_purchase = sorted_entries(entries, purchase_counts, {})
      selected = sorted_by_purchase.select { |entry| purchase_counts[entry.plan&.id].to_i.positive? }
                                   .first(TRENDING_LIMIT)

      if selected.size < TRENDING_LIMIT
        usage_counts = usage_counts_for(entries)
        fallback = (entries - selected)
                   .sort_by { |entry| [-usage_counts[entry.plan&.id].to_i, entry.product.sort_order.to_i] }
                   .select { |entry| usage_counts[entry.plan&.id].to_i.positive? }
        selected += fallback.first(TRENDING_LIMIT - selected.size)
      end

      return [] if selected.empty?

      selected.map do |entry|
        product = entry.product
        TrendingCard.new(
          title: product.title_for(locale),
          image: image_for(product),
          cta_label_key: "dashboard.marketplace.cta.explore",
          cta_url: dashboard_marketplace_product_path(product)
        )
      end
    end

    def sorted_entries(entries, purchase_counts, usage_counts)
      entries.sort_by do |entry|
        plan_id = entry.plan&.id
        [
          -purchase_counts[plan_id].to_i,
          -usage_counts[plan_id].to_i,
          entry.product.sort_order.to_i,
          entry.product.title_for(locale).to_s
        ]
      end
    end

    def purchase_counts_for(entries, window_days: nil)
      plan_ids = entries.map { |entry| entry.plan&.id }.compact
      return {} if plan_ids.empty?

      scope = MarketplacePurchase.where(billing_plan_id: plan_ids)
      if window_days
        scope = scope.where(purchased_at: window_days.days.ago..Time.current)
      end
      scope.group(:billing_plan_id).count
    end

    def usage_counts_for(entries)
      ea_ids = entries.flat_map { |entry| entry.expert_advisors.map(&:id) }
      course_ids = entries.flat_map { |entry| entry.courses.map(&:id) }
      addon_ea_ids = entries.filter_map { |entry| entry.addonable if entry.addonable.is_a?(ExpertAdvisor) }.map(&:id)
      addon_course_ids = entries.filter_map { |entry| entry.addonable if entry.addonable.is_a?(Course) }.map(&:id)

      all_ea_ids = (ea_ids + addon_ea_ids).uniq
      all_course_ids = (course_ids + addon_course_ids).uniq

      license_counts = if all_ea_ids.any?
                         License.active_or_trial.where(expert_advisor_id: all_ea_ids).group(:expert_advisor_id).count
                       else
                         {}
                       end
      enrollment_counts = if all_course_ids.any?
                            CourseEnrollment.where(course_id: all_course_ids).group(:course_id).count
                          else
                            {}
                          end

      entries.each_with_object({}) do |entry, counts|
        total = entry.expert_advisors.sum { |ea| license_counts[ea.id].to_i }
        total += entry.courses.sum { |course| enrollment_counts[course.id].to_i }

        addonable = entry.addonable
        if addonable.is_a?(ExpertAdvisor)
          total += license_counts[addonable.id].to_i
        elsif addonable.is_a?(Course)
          total += enrollment_counts[addonable.id].to_i
        end

        counts[entry.plan&.id] = total
      end
    end

    def metric_counts_for(entries, purchase_counts, usage_counts)
      entries.each_with_object({}) do |entry, counts|
        plan_id = entry.plan&.id
        purchase_count = purchase_counts[plan_id].to_i
        usage_count = usage_counts[plan_id].to_i
        counts[plan_id] = purchase_count.positive? ? purchase_count : usage_count
      end
    end

    def price_display_for(plan)
      return I18n.t("dashboard.marketplace.pricing.free", locale: locale) unless plan

      ActionController::Base.helpers.number_to_currency(plan.amount_cents.to_i / 100.0, unit: "$", precision: 2)
    end

    def image_for(product)
      return product.image if product.image.attached?

      DEFAULT_PLACEHOLDER
    end

    def rating_from_metric(value, max_value)
      base_rating = 3.0
      range = 2.0
      return base_rating if max_value.to_f <= 0

      rating = base_rating + (value.to_f / max_value.to_f) * range
      rating = rating.clamp(base_rating, base_rating + range)
      rating.round(1)
    end

    def pages_for(items)
      total_items = items.size
      return 1 if total_items <= 0

      (total_items / PAGE_SIZE.to_f).ceil
    end
  end
end
