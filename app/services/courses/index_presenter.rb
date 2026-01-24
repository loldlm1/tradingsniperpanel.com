module Courses
  class IndexPresenter
    include Rails.application.routes.url_helpers

    Filter = Struct.new(:label, :value, :count, keyword_init: true)
    Card = Struct.new(
      :index,
      :entry,
      :course,
      :type_label,
      :category_label,
      :summary,
      :modules_count,
      :lessons_count,
      :duration_seconds,
      :progress_percent,
      :progress_label,
      :accessible,
      :unlock_url,
      :status_label,
      :status_class,
      :details_url,
      :filter_tags,
      :search_text,
      :visible_by_default,
      :published_at,
      :position,
      :slug,
      keyword_init: true
    )

    def initialize(entries:, locale: I18n.locale, marketplace_available: false, page: nil, items: 8)
      @entries = Array(entries)
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
      @cards ||= sorted_entries.map.with_index { |entry, index| build_card(entry, index) }
    end

    def pagy
      @pagy ||= Pagy::Offset.new(count: entries.size, page: page, limit: items)
    end

    def filters
      @filters ||= category_filters + tag_filters + access_filters
    end

    def total_count
      entries.size
    end

    def default_url_options
      { locale: @locale }
    end

    private

    attr_reader :locale, :marketplace_available, :offset

    def preload_context
      @marketplace_products_by_course_id = marketplace_available ? load_marketplace_products : {}
    end

    def sorted_entries
      @sorted_entries ||= entries.sort_by do |entry|
        course = entry.course
        published_at = course.published_at || course.created_at
        [
          -(published_at&.to_i || 0),
          course.position.to_i,
          course.slug.to_s
        ]
      end
    end

    def build_card(entry, index)
      course = entry.course
      lessons = course.course_modules.flat_map(&:course_lessons)
      modules_count = course.course_modules.size
      lessons_count = lessons.size
      duration_seconds = lessons.sum { |lesson| lesson.duration_seconds.to_i }
      summary = course.summary_for(locale).presence || course.description_for(locale)
      access_status = access_status_for(entry, course)
      progress_percent = entry.progress_percent.to_i
      category_label = category_label_for(course.category)

      Card.new(
        index: index,
        entry: entry,
        course: course,
        type_label: type_label_for(category_label),
        category_label: category_label,
        summary: summary,
        modules_count: modules_count,
        lessons_count: lessons_count,
        duration_seconds: duration_seconds,
        progress_percent: progress_percent,
        progress_label: progress_label_for(progress_percent, entry.accessible),
        accessible: entry.accessible,
        unlock_url: unlock_url_for(entry),
        status_label: status_label_for(entry, access_status),
        status_class: status_class_for(entry, access_status),
        details_url: dashboard_course_path(course, locale: locale),
        filter_tags: filter_tags_for(course, access_status),
        search_text: build_search_text(course, category_label, access_status),
        visible_by_default: visible_by_default?(index),
        published_at: (course.published_at || course.created_at)&.iso8601,
        position: course.position,
        slug: course.slug
      )
    end

    def type_label_for(category_label)
      type = I18n.t("dashboard.courses.card.type_label")
      I18n.t("dashboard.courses.card.type_category", type: type, category: category_label)
    end

    def category_label_for(category)
      I18n.t("dashboard.courses.categories.#{category}", default: category.to_s.humanize)
    end

    def access_status_for(entry, course)
      return "free" if course.free_access?
      return "unlocked" if entry.accessible

      "locked"
    end

    def unlock_url_for(entry)
      return if entry.accessible

      if marketplace_available
        product = @marketplace_products_by_course_id[entry.course.id]
        return dashboard_marketplace_product_path(product, locale: locale) if product.present?
      end

      plan = entry.cta_plan
      return if plan.blank?

      dashboard_plans_path(price_key: plan.key, locale: locale)
    end

    def status_label_for(entry, access_status)
      return I18n.t("dashboard.courses.status.active") if entry.accessible

      I18n.t("dashboard.courses.badges.#{access_status}", default: access_status.to_s.humanize)
    end

    def status_class_for(entry, access_status)
      return "bg-emerald-100 text-emerald-700 dark:bg-emerald-500/20 dark:text-emerald-100" if entry.accessible

      return "bg-gray-100 text-gray-700 dark:bg-gray-700/60 dark:text-gray-200" if access_status == "locked"

      "bg-emerald-100 text-emerald-700 dark:bg-emerald-500/20 dark:text-emerald-100"
    end

    def progress_label_for(progress_percent, accessible)
      return nil unless accessible
      return I18n.t("dashboard.courses.progress.status.completed") if progress_percent >= 100
      return I18n.t("dashboard.courses.progress.status.in_progress") if progress_percent.positive?

      nil
    end

    def filter_tags_for(course, access_status)
      tags = []
      tags << course.category
      tags.concat(course.tag_list)
      tags << access_status
      tags.map { |tag| normalize_tag(tag) }.reject(&:blank?).uniq.join("|")
    end

    def build_search_text(course, category_label, access_status)
      parts = [
        course.title_for(locale),
        course.summary_for(locale),
        course.description_for(locale),
        course.category,
        category_label,
        access_status,
        access_label_for(access_status),
        *course.tag_list
      ].compact

      parts.join(" ").downcase
    end

    def visible_by_default?(index)
      return true if items.to_i <= 0

      index >= offset && index < (offset + items)
    end

    def access_label_for(access_status)
      I18n.t("dashboard.courses.badges.#{access_status}", default: access_status.to_s.humanize)
    end

    def category_filters
      counts = Hash.new(0)
      entries.each do |entry|
        category = normalize_tag(entry.course.category)
        next if category.blank?

        counts[category] += 1
      end

      counts.sort_by { |category, count| [-count, category] }.map do |category, count|
        Filter.new(
          label: category_label_for(category),
          value: category,
          count: count
        )
      end
    end

    def tag_filters
      entries_for_tags = entries_with_progress
      entries_for_tags = entries if entries_for_tags.empty?

      counts, labels = tag_counts_for(entries_for_tags)
      return [] if counts.empty?

      counts.sort_by { |tag, count| [-count, tag] }.first(5).map do |tag, count|
        Filter.new(label: labels[tag] || tag, value: tag, count: count)
      end
    end

    def entries_with_progress
      entries.select { |entry| entry.progress_percent.to_i.positive? }
    end

    def tag_counts_for(entries_for_tags)
      counts = Hash.new(0)
      labels = {}

      entries_for_tags.each do |entry|
        entry.course.tag_list.each do |tag|
          normalized = normalize_tag(tag)
          next if normalized.blank?

          counts[normalized] += 1
          labels[normalized] ||= tag.to_s.strip
        end
      end

      [counts, labels]
    end

    def load_marketplace_products
      course_ids = entries.map { |entry| entry.course.id }
      return {} if course_ids.empty?

      products = MarketplaceProduct.active
                                   .joins(billing_plan: :course_plan_entitlements)
                                   .where(course_plan_entitlements: { course_id: course_ids })
                                   .includes(billing_plan: :courses)
                                   .order(:sort_order)

      products.each_with_object({}) do |product, map|
        product.courses.each do |course|
          map[course.id] ||= product
        end
      end
    end

    def access_filters
      counts = Hash.new(0)

      entries.each do |entry|
        course = entry.course
        status = access_status_for(entry, course)
        counts[status] += 1
      end

      %w[free unlocked locked].filter_map do |status|
        count = counts[status]
        next if count.to_i.zero?

        Filter.new(
          label: access_label_for(status),
          value: status,
          count: count
        )
      end
    end

    def normalize_tag(value)
      value.to_s.strip.downcase
    end
  end
end
