module Marketplace
  class IndexPresenter
    include Rails.application.routes.url_helpers

    TAG_LIMIT = 8
    POPULAR_LICENSE_THRESHOLD = 5
    BEST_SELLING_WINDOW_DAYS = 30
    RETENTION_WINDOW_DAYS = 30
    TRENDING_WINDOW_DAYS = 7
    PNL_WINDOW_DAYS = 30

    COURSE_PLACEHOLDERS = %w[
      mosaic/images/applications-image-01.jpg
      mosaic/images/applications-image-02.jpg
      mosaic/images/applications-image-03.jpg
      mosaic/images/applications-image-04.jpg
    ].freeze

    DIGITAL_GOODS_PLACEHOLDERS = %w[
      mosaic/images/applications-image-05.jpg
      mosaic/images/applications-image-06.jpg
      mosaic/images/applications-image-07.jpg
      mosaic/images/applications-image-08.jpg
    ].freeze

    CATEGORY_PLACEHOLDERS = %w[
      mosaic/images/shop-category-01.png
      mosaic/images/shop-category-02.png
      mosaic/images/shop-category-03.png
      mosaic/images/shop-category-04.png
    ].freeze

    TRENDING_PLACEHOLDERS = %w[
      mosaic/images/applications-image-17.jpg
      mosaic/images/applications-image-18.jpg
      mosaic/images/applications-image-19.jpg
      mosaic/images/applications-image-20.jpg
    ].freeze

    TABS = [
      { key: :all, label_key: "dashboard.marketplace.tabs.all" },
      { key: :courses, label_key: "dashboard.marketplace.tabs.courses" },
      { key: :digital_goods, label_key: "dashboard.marketplace.tabs.digital_goods" },
      { key: :online_events, label_key: "dashboard.marketplace.tabs.online_events" }
    ].freeze

    CourseCard = Struct.new(
      :course,
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
      :expert_advisor,
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
      TABS
    end

    def filtering?
      query.present? || selected_tags.any?
    end

    def empty_state?
      return true if selected_tab == :online_events
      return false if show_courses? && course_cards.any?
      return false if show_digital_goods? && digital_goods_cards.any?

      true
    end

    def show_courses?
      selected_tab == :all || selected_tab == :courses
    end

    def show_digital_goods?
      selected_tab == :all || selected_tab == :digital_goods
    end

    def show_categories?
      selected_tab == :all && !empty_state?
    end

    def show_trending?
      selected_tab == :all && !empty_state?
    end

    def show_online_events?
      false
    end

    def tags
      return [] if selected_tab == :online_events

      counts = {}
      if selected_tab == :all || selected_tab == :courses
        counts = merge_tag_counts(counts, tag_counts_for(search_course_scope, "Course"))
      end
      if selected_tab == :all || selected_tab == :digital_goods
        counts = merge_tag_counts(counts, tag_counts_for(search_expert_advisor_scope, "ExpertAdvisor"))
      end

      ordered = counts.sort_by { |(name, count)| [-count, name.downcase] }.map(&:first)
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
      return :courses if normalized == "courses"
      return :digital_goods if normalized == "digital_goods"
      return :online_events if normalized == "online_events"

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

    def merge_tag_counts(base, new_counts)
      new_counts.each_with_object(base.dup) do |(name, count), merged|
        merged[name] = merged.fetch(name, 0) + count.to_i
      end
    end

    def tag_counts_for(scope, taggable_type)
      return {} if scope.none?

      taggings = ActsAsTaggableOn::Tagging.where(
        context: "tags",
        taggable_type: taggable_type,
        taggable_id: scope.reselect(:id).unscope(:order)
      )

      taggings.joins(:tag).group("tags.name").count
    end

    def search_terms
      @search_terms ||= query.to_s.downcase.split(/\s+/).map(&:strip).reject(&:blank?)
    end

    def matching_plan_ids
      return BillingPlan.none if search_terms.empty?
      return @matching_plan_ids if defined?(@matching_plan_ids)

      plans = BillingPlan.active.left_joins(:marketplace_product)
      plan_table = BillingPlan.arel_table
      product_table = MarketplaceProduct.arel_table

      conditions = search_terms.map do |term|
        pattern = "%#{ActiveRecord::Base.sanitize_sql_like(term)}%"
        plan_table[:name].matches(pattern)
          .or(plan_table[:key].matches(pattern))
          .or(product_table[:title_en].matches(pattern))
          .or(product_table[:title_es].matches(pattern))
          .or(product_table[:summary_en].matches(pattern))
          .or(product_table[:summary_es].matches(pattern))
          .or(product_table[:description_en].matches(pattern))
          .or(product_table[:description_es].matches(pattern))
      end

      combined = conditions.reduce { |memo, condition| memo.or(condition) }
      @matching_plan_ids = plans.where(combined).select(:id)
    end

    def matching_plan_ids_present?
      @matching_plan_ids_present ||= matching_plan_ids.exists?
    end

    def apply_text_search(scope, columns, terms)
      return nil if terms.blank?

      table = scope.klass.arel_table
      conditions = terms.map do |term|
        pattern = "%#{ActiveRecord::Base.sanitize_sql_like(term)}%"
        columns.map { |column| table[column].matches(pattern) }.reduce(:or)
      end

      scope.where(conditions.reduce(:or))
    end

    def combine_scopes(*scopes)
      scopes.compact.reduce { |memo, scope| memo.or(scope) }
    end

    def base_course_scope
      Course.published
    end

    def course_search_columns
      %i[title_en title_es summary_en summary_es description_en description_es category]
    end

    def search_course_scope
      return @search_course_scope if defined?(@search_course_scope)

      scope = base_course_scope
      if search_terms.empty?
        @search_course_scope = scope
      else
        text_scope = apply_text_search(scope, course_search_columns, search_terms)
        plan_scope = nil
        if matching_plan_ids_present?
          plan_course_ids = CoursePlanEntitlement.where(billing_plan_id: matching_plan_ids).select(:course_id)
          plan_scope = scope.where(id: plan_course_ids)
        end
        combined = combine_scopes(text_scope, plan_scope)
        @search_course_scope = combined ? combined.distinct : scope.none
      end
    end

    def filtered_course_scope
      scope = search_course_scope
      return scope if selected_tags.empty?

      scope.tagged_with(selected_tags, any: true)
    end

    def base_expert_advisor_scope
      ExpertAdvisor.active
    end

    def search_expert_advisor_scope
      return @search_expert_advisor_scope if defined?(@search_expert_advisor_scope)

      scope = base_expert_advisor_scope
      if search_terms.empty?
        @search_expert_advisor_scope = scope
      else
        type_terms = search_terms & ExpertAdvisor.ea_types.keys
        text_terms = search_terms - type_terms
        text_scope = apply_text_search(scope, %i[name description], text_terms)
        type_scope = type_terms.any? ? scope.where(ea_type: type_terms) : nil
        plan_scope = nil
        if matching_plan_ids_present?
          plan_ea_ids = BillingPlanEntitlement.where(billing_plan_id: matching_plan_ids).select(:expert_advisor_id)
          plan_scope = scope.where(id: plan_ea_ids)
        end

        combined = combine_scopes(text_scope, type_scope, plan_scope)
        @search_expert_advisor_scope = combined ? combined.distinct : scope.none
      end
    end

    def filtered_expert_advisor_scope
      scope = search_expert_advisor_scope
      return scope if selected_tags.empty?

      scope.tagged_with(selected_tags, any: true)
    end

    def addon_matches_filters?(addon)
      return false unless matches_query_for_addon?(addon)
      return true if selected_tags.empty?

      addonable = addon.addonable
      return false unless addonable.respond_to?(:tag_list)

      tag_list = addonable.tag_list.map(&:downcase)
      (tag_list & selected_tags).any?
    end

    def matches_query_for_addon?(addon)
      return true if search_terms.empty?

      product = addon.marketplace_product
      plan = addon.billing_plan
      matches_any_term?(
        addon.key,
        plan&.name,
        plan&.key,
        product&.title_en,
        product&.title_es,
        product&.summary_en,
        product&.summary_es,
        product&.description_en,
        product&.description_es
      )
    end

    def matches_any_term?(*values)
      return true if search_terms.empty?

      haystack = values.compact.map { |value| value.to_s.downcase }
      search_terms.any? { |term| haystack.any? { |value| value.include?(term) } }
    end

    def best_course_ids_by_enrollments(scope, window_days:)
      CourseEnrollment.where(course_id: scope.reselect(:id))
                      .where(created_at: window_days.days.ago..Time.current)
                      .group(:course_id)
                      .order(Arel.sql("COUNT(course_enrollments.id) DESC"))
                      .pluck(:course_id)
    end

    def best_course_ids_by_completion(scope)
      CourseEnrollment.where(course_id: scope.reselect(:id))
                      .group(:course_id)
                      .order(Arel.sql("AVG(course_enrollments.progress_percent) DESC"))
                      .pluck(:course_id)
    end

    def most_recent_course_ids(scope)
      scope.distinct(false).reorder(published_at: :desc, created_at: :desc).pluck(:id)
    end

    def recommended_course_id(scope, fallback_ids:, used_ids:)
      return pick_unique_id(fallback_ids, used_ids) unless user

      enrollment = CourseEnrollment.where(user: user).where("progress_percent < 100").order(progress_percent: :desc).first
      if enrollment && scope.where(id: enrollment.course_id).exists? && !used_ids.include?(enrollment.course_id)
        return enrollment.course_id
      end

      pick_unique_id(fallback_ids, used_ids)
    end

    def pick_unique_id(candidates, used_ids)
      Array(candidates).find { |candidate| candidate.present? && !used_ids.include?(candidate) }
    end

    def best_expert_advisor_ids_by_usage(scope)
      License.active_or_trial.where(expert_advisor_id: scope.reselect(:id))
                             .group(:expert_advisor_id)
                             .order(Arel.sql("COUNT(licenses.id) DESC"))
                             .pluck(:expert_advisor_id)
    end

    def best_expert_advisor_ids_by_pnl(scope)
      from_ts = PNL_WINDOW_DAYS.days.ago.to_i
      to_ts = Time.current.to_i

      BrokerAccountDailyResult.joins(broker_account: { license: :expert_advisor })
                              .where(licenses: { expert_advisor_id: scope.reselect(:id) })
                              .where(result_timestamp: from_ts..to_ts)
                              .group("licenses.expert_advisor_id")
                              .order(Arel.sql("SUM(broker_account_daily_results.result_value) DESC"))
                              .pluck("licenses.expert_advisor_id")
    end

    def best_expert_advisor_ids_by_retention(scope)
      from_ts = RETENTION_WINDOW_DAYS.days.ago.to_i
      to_ts = Time.current.to_i

      BrokerAccountDailyResult.joins(broker_account: :license)
                              .where(licenses: { expert_advisor_id: scope.reselect(:id), status: License::STATUSES.values_at(:active, :trial) })
                              .where(result_timestamp: from_ts..to_ts)
                              .group("licenses.expert_advisor_id")
                              .order(Arel.sql("COUNT(DISTINCT licenses.id) DESC"))
                              .pluck("licenses.expert_advisor_id")
    end

    def most_recent_expert_advisor_ids(scope)
      scope.distinct(false).reorder(created_at: :desc).pluck(:id)
    end

    def build_course_cards
      scope = filtered_course_scope
      return [] if scope.none?

      fallback_ids = scope.distinct(false).reorder(:position, :title_en).pluck(:id)
      used_ids = []
      selected_ids = []

      best_selling_ids = best_course_ids_by_enrollments(scope, window_days: BEST_SELLING_WINDOW_DAYS)
      selected_ids << pick_unique_id(best_selling_ids + fallback_ids, used_ids)
      used_ids.concat(selected_ids.compact)

      completion_ids = best_course_ids_by_completion(scope)
      selected_ids << pick_unique_id(completion_ids + fallback_ids, used_ids)
      used_ids.concat(selected_ids.compact)

      recent_ids = most_recent_course_ids(scope)
      selected_ids << pick_unique_id(recent_ids + fallback_ids, used_ids)
      used_ids.concat(selected_ids.compact)

      selected_ids << recommended_course_id(scope, fallback_ids: fallback_ids, used_ids: used_ids)
      selected_ids.compact!
      return [] if selected_ids.empty?

      courses = scope.where(id: selected_ids).includes(
        billing_plans: { marketplace_product: { image_attachment: :blob } },
        addons: { billing_plan: { marketplace_product: { image_attachment: :blob } } }
      )
      course_map = courses.index_by(&:id)

      module_counts = CourseModule.where(course_id: selected_ids).group(:course_id).count
      lesson_counts = CourseLesson.joins(:course_module).where(course_modules: { course_id: selected_ids }).group("course_modules.course_id").count
      duration_sums = CourseLesson.joins(:course_module).where(course_modules: { course_id: selected_ids }).group("course_modules.course_id").sum(:duration_seconds)
      progress_map = CourseEnrollment.where(course_id: selected_ids).group(:course_id).average(:progress_percent)

      selected_ids.map.with_index do |course_id, index|
        course = course_map[course_id]
        next unless course

        plan = best_priced_plan(course.billing_plans, course.addons)
        CourseCard.new(
          course: course,
          title: course.title_for(locale),
          image: image_for_plan(plan, COURSE_PLACEHOLDERS[index % COURSE_PLACEHOLDERS.length]),
          rating: rating_from_percent(progress_map[course_id].to_f),
          price_display: price_display_for(plan),
          duration_seconds: duration_sums[course_id].to_i,
          lessons_count: lesson_counts[course_id].to_i,
          modules_count: module_counts[course_id].to_i,
          category: course.category,
          cta_label_key: course_cta_label_key(index),
          detail_url: dashboard_course_path(course)
        )
      end.compact
    end

    def build_digital_goods_cards
      scope = filtered_expert_advisor_scope
      return [] if scope.none?

      fallback_ids = scope.distinct(false).ordered_by_rank.pluck(:id)
      used_ids = []
      selected_ids = []

      usage_ids = best_expert_advisor_ids_by_usage(scope)
      selected_ids << pick_unique_id(usage_ids + fallback_ids, used_ids)
      used_ids.concat(selected_ids.compact)

      pnl_ids = best_expert_advisor_ids_by_pnl(scope)
      selected_ids << pick_unique_id(pnl_ids + fallback_ids, used_ids)
      used_ids.concat(selected_ids.compact)

      recent_ids = most_recent_expert_advisor_ids(scope)
      selected_ids << pick_unique_id(recent_ids + fallback_ids, used_ids)
      used_ids.concat(selected_ids.compact)

      retention_ids = best_expert_advisor_ids_by_retention(scope)
      selected_ids << pick_unique_id(retention_ids + fallback_ids, used_ids)
      selected_ids.compact!
      return [] if selected_ids.empty?

      expert_advisors = scope.where(id: selected_ids).includes(
        billing_plans: { marketplace_product: { image_attachment: :blob } },
        addons: { billing_plan: { marketplace_product: { image_attachment: :blob } } }
      )
      ea_map = expert_advisors.index_by(&:id)

      license_counts = License.active_or_trial.where(expert_advisor_id: selected_ids).group(:expert_advisor_id).count
      pnl_map = pnl_map_for(selected_ids)
      retention_map = retention_map_for(selected_ids)

      usage_max = license_counts.values.max.to_f
      pnl_max = pnl_map.values.map(&:to_f).max.to_f
      retention_max = retention_map.values.max.to_f

      selected_ids.map.with_index do |ea_id, index|
        expert_advisor = ea_map[ea_id]
        next unless expert_advisor

        plan = best_priced_plan(expert_advisor.billing_plans, expert_advisor.addons)
        metric_rating = case index
                        when 0 then rating_from_metric(license_counts[ea_id].to_f, usage_max)
                        when 1 then rating_from_metric(pnl_map[ea_id].to_f, pnl_max)
                        when 2 then rating_from_metric(license_counts[ea_id].to_f, usage_max)
                        else rating_from_metric(retention_map[ea_id].to_f, retention_max)
                        end

        DigitalGoodCard.new(
          expert_advisor: expert_advisor,
          title: expert_advisor.name,
          summary: expert_advisor.description,
          image: image_for_plan(plan, DIGITAL_GOODS_PLACEHOLDERS[index % DIGITAL_GOODS_PLACEHOLDERS.length]),
          rating: metric_rating,
          rating_count: license_counts[ea_id].to_i,
          price_display: price_display_for(plan),
          cta_label_key: digital_good_cta_label_key(index),
          detail_url: dashboard_expert_advisor_path(expert_advisor),
          popular: index.zero? && license_counts[ea_id].to_i >= POPULAR_LICENSE_THRESHOLD
        )
      end.compact
    end

    def pnl_map_for(selected_ids)
      return {} if selected_ids.empty?

      from_ts = PNL_WINDOW_DAYS.days.ago.to_i
      to_ts = Time.current.to_i

      BrokerAccountDailyResult.joins(broker_account: :license)
                              .where(licenses: { expert_advisor_id: selected_ids })
                              .where(result_timestamp: from_ts..to_ts)
                              .group("licenses.expert_advisor_id")
                              .sum(:result_value)
    end

    def retention_map_for(selected_ids)
      return {} if selected_ids.empty?

      from_ts = RETENTION_WINDOW_DAYS.days.ago.to_i
      to_ts = Time.current.to_i

      BrokerAccountDailyResult.joins(broker_account: :license)
                              .where(licenses: { expert_advisor_id: selected_ids, status: License::STATUSES.values_at(:active, :trial) })
                              .where(result_timestamp: from_ts..to_ts)
                              .group("licenses.expert_advisor_id")
                              .distinct
                              .count("licenses.id")
    end

    def build_category_cards
      cards = []
      cards << CategoryCard.new(
        title: I18n.t("dashboard.marketplace.categories.expert_advisors", locale: locale),
        image: CATEGORY_PLACEHOLDERS[0],
        cta_label_key: "dashboard.marketplace.cta.explore",
        cta_url: dashboard_marketplace_path(tab: :digital_goods, q: "ea_robot")
      )
      cards << CategoryCard.new(
        title: I18n.t("dashboard.marketplace.categories.tools", locale: locale),
        image: CATEGORY_PLACEHOLDERS[1],
        cta_label_key: "dashboard.marketplace.cta.explore",
        cta_url: dashboard_marketplace_path(tab: :digital_goods, q: "ea_tool")
      )

      top_category = top_course_category
      if top_category.present?
        category_label = I18n.t("dashboard.courses.categories.#{top_category}", locale: locale, default: top_category.to_s.humanize)
        cards << CategoryCard.new(
          title: category_label,
          image: CATEGORY_PLACEHOLDERS[2],
          cta_label_key: "dashboard.marketplace.cta.explore",
          cta_url: dashboard_marketplace_path(tab: :courses, q: top_category)
        )
      end

      cards << CategoryCard.new(
        title: I18n.t("dashboard.marketplace.categories.addons_bundles", locale: locale),
        image: CATEGORY_PLACEHOLDERS[3],
        cta_label_key: "dashboard.marketplace.cta.explore",
        cta_url: dashboard_marketplace_path(q: "addon bundle")
      )

      cards.compact
    end

    def top_course_category
      @top_course_category ||= begin
        category = CourseEnrollment.joins(:course)
                                   .merge(Course.published)
                                   .group("courses.category")
                                   .order(Arel.sql("COUNT(course_enrollments.id) DESC"))
                                   .limit(1)
                                   .pluck("courses.category")
                                   .first
        category.presence || Course.published.order(:position).limit(1).pluck(:category).first
      end
    end

    def build_trending_cards
      cards = []
      cards << trending_expert_advisor_card
      cards << trending_course_card
      cards << trending_addon_card
      cards << trending_plan_card
      cards.compact.each_with_index.map do |card, index|
        next card unless card.image.nil?

        card.image = TRENDING_PLACEHOLDERS[index % TRENDING_PLACEHOLDERS.length]
        card
      end.compact
    end

    def trending_expert_advisor_card
      scope = filtered_expert_advisor_scope
      return nil if scope.none?

      from_time = TRENDING_WINDOW_DAYS.days.ago
      purchase_ids = MarketplacePurchase.joins(billing_plan: :expert_advisors)
                                         .where(expert_advisors: { id: scope.reselect(:id) })
                                         .where(purchased_at: from_time..Time.current)
                                         .group("expert_advisors.id")
                                         .order(Arel.sql("COUNT(marketplace_purchases.id) DESC"))
                                         .pluck("expert_advisors.id")

      if purchase_ids.empty?
        purchase_ids = License.where(expert_advisor_id: scope.reselect(:id))
                              .where(created_at: from_time..Time.current)
                              .group(:expert_advisor_id)
                              .order(Arel.sql("COUNT(licenses.id) DESC"))
                              .pluck(:expert_advisor_id)
      end

      expert_advisor_id = purchase_ids.first
      expert_advisor = expert_advisor_id ? scope.find_by(id: expert_advisor_id) : nil
      return nil unless expert_advisor

      plan = best_priced_plan(expert_advisor.billing_plans, expert_advisor.addons)
      TrendingCard.new(
        title: expert_advisor.name,
        image: image_for_plan(plan, nil),
        cta_label_key: "dashboard.marketplace.cta.explore",
        cta_url: dashboard_expert_advisor_path(expert_advisor)
      )
    end

    def trending_course_card
      scope = filtered_course_scope
      return nil if scope.none?

      from_time = TRENDING_WINDOW_DAYS.days.ago
      course_ids = CourseEnrollment.where(course_id: scope.reselect(:id))
                                   .where(created_at: from_time..Time.current)
                                   .group(:course_id)
                                   .order(Arel.sql("COUNT(course_enrollments.id) DESC"))
                                   .pluck(:course_id)
      course_id = course_ids.first
      course = course_id ? scope.find_by(id: course_id) : nil
      return nil unless course

      plan = best_priced_plan(course.billing_plans, course.addons)
      TrendingCard.new(
        title: course.title_for(locale),
        image: image_for_plan(plan, nil),
        cta_label_key: "dashboard.marketplace.cta.explore",
        cta_url: dashboard_course_path(course)
      )
    end

    def trending_addon_card
      from_time = TRENDING_WINDOW_DAYS.days.ago
      addon_plan_ids = Addon.pluck(:billing_plan_id)
      return nil if addon_plan_ids.empty?

      plan_ids = MarketplacePurchase.where(billing_plan_id: addon_plan_ids)
                                    .where(purchased_at: from_time..Time.current)
                                    .group(:billing_plan_id)
                                    .order(Arel.sql("COUNT(marketplace_purchases.id) DESC"))
                                    .pluck(:billing_plan_id)
      return nil if plan_ids.empty?

      addons = Addon.where(billing_plan_id: plan_ids).includes(
        billing_plan: { marketplace_product: { image_attachment: :blob } },
        addonable: :tags
      )
      addon_map = addons.index_by(&:billing_plan_id)
      addon = plan_ids.find do |plan_id|
        candidate = addon_map[plan_id]
        candidate if candidate && addon_matches_filters?(candidate)
      end
      addon = addon_map[addon] if addon
      return nil unless addon

      product = addon.marketplace_product
      title = product&.title_for(locale) || addon.key.to_s.humanize

      TrendingCard.new(
        title: title,
        image: product&.image&.attached? ? product.image : nil,
        cta_label_key: "dashboard.marketplace.cta.explore",
        cta_url: product ? dashboard_marketplace_product_path(product) : dashboard_marketplace_path
      )
    end

    def trending_plan_card
      return nil if selected_tags.any?

      plan = most_chosen_plan
      return nil unless plan
      return nil unless matches_any_term?(plan.name, plan.key)

      TrendingCard.new(
        title: plan.name,
        image: nil,
        cta_label_key: "dashboard.marketplace.cta.explore",
        cta_url: dashboard_plans_path(price_key: plan.key)
      )
    end

    def most_chosen_plan
      return nil unless defined?(Pay::Subscription)

      price_ids = Pay::Subscription.where(status: "active")
                                   .group(:processor_plan)
                                   .order(Arel.sql("COUNT(pay_subscriptions.id) DESC"))
                                   .pluck(:processor_plan)

      price_ids.each do |price_id|
        plan = BillingPlan.active.subscription.find_by(stripe_price_id: price_id)
        return plan if plan
      end

      nil
    end

    def best_priced_plan(plans, addons)
      plan_list = Array(plans).select(&:present?)
      addon_plans = Array(addons).map(&:billing_plan).compact
      candidates = plan_list + addon_plans
      candidates.min_by { |plan| [plan.amount_cents.to_i, plan.sort_order.to_i] }
    end

    def price_display_for(plan)
      return I18n.t("dashboard.marketplace.pricing.free", locale: locale) unless plan

      ActionController::Base.helpers.number_to_currency(plan.amount_cents.to_i / 100.0, unit: "$", precision: 2)
    end

    def image_for_plan(plan, fallback)
      product = plan&.marketplace_product
      return product.image if product&.image&.attached?
      fallback
    end

    def rating_from_percent(value)
      base_rating = 3.5
      range = 1.5
      percent = value.to_f.clamp(0.0, 100.0)
      rating = base_rating + (percent / 100.0) * range
      rating.round(1)
    end

    def rating_from_metric(value, max_value)
      base_rating = 3.5
      range = 1.5
      return base_rating if max_value.to_f <= 0

      rating = base_rating + (value.to_f / max_value.to_f) * range
      rating = rating.clamp(base_rating, base_rating + range)
      rating.round(1)
    end

    def course_cta_label_key(index)
      case index
      when 0 then "dashboard.marketplace.cta.buy_course"
      when 1 then "dashboard.marketplace.cta.view_course"
      when 2 then "dashboard.marketplace.cta.explore_course"
      else "dashboard.marketplace.cta.continue_course"
      end
    end

    def digital_good_cta_label_key(index)
      case index
      when 0 then "dashboard.marketplace.cta.buy_ea"
      when 1 then "dashboard.marketplace.cta.view_performance"
      when 2 then "dashboard.marketplace.cta.explore_ea"
      else "dashboard.marketplace.cta.view_ea"
      end
    end
  end
end
