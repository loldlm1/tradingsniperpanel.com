module Dashboard
  class ProductReleaseNotificationPresenter
    include Rails.application.routes.url_helpers

    Release = Struct.new(
      :record,
      :summary,
      :published_at_label,
      :items,
      keyword_init: true
    )

    Item = Struct.new(
      :record,
      :badge_label,
      :title,
      :path,
      keyword_init: true
    )

    def initialize(user:, accessible_eas:, accessible_courses:, marketplace_available:, locale: I18n.locale)
      @user = user
      @accessible_eas = Array(accessible_eas)
      @accessible_courses = Array(accessible_courses)
      @marketplace_available = marketplace_available
      @locale = locale.presence || I18n.locale
    end

    def call
      self
    end

    def present?
      releases.any?
    end

    def unread?
      present?
    end

    def release
      releases.first&.record
    end

    def items
      @items ||= releases.flat_map(&:items)
    end

    def published_at_label
      releases.first&.published_at_label
    end

    def release_summary
      releases.first&.summary || I18n.t("dashboard.product_releases.empty")
    end

    def releases
      @releases ||= visible_releases.map { |entry| build_release(entry) }
    end

    def collection_summary
      return I18n.t("dashboard.product_releases.empty") unless present?

      I18n.t("dashboard.product_releases.collection_summary", count: releases.size, item_count: items.size)
    end

    def clear_path
      clear_dashboard_product_releases_path(locale: locale)
    end

    def dismiss_path
      clear_path
    end

    def default_url_options
      { locale: locale }
    end

    private

    attr_reader :user, :accessible_eas, :accessible_courses, :marketplace_available, :locale

    def visible_releases
      ProductReleases::UnreadVisibleReleases.new(
        user: user,
        accessible_eas: accessible_eas,
        accessible_courses: accessible_courses,
        marketplace_available: marketplace_available
      ).call
    end

    def build_release(entry)
      Release.new(
        record: entry.release,
        summary: I18n.t("dashboard.product_releases.summary", count: entry.items.size),
        published_at_label: I18n.l(entry.release.published_at, format: :short_with_year, locale: locale),
        items: entry.items.map { |item| build_item(item) }
      )
    end

    def build_item(item)
      Item.new(
        record: item,
        badge_label: I18n.t("dashboard.product_releases.badges.#{item.product_kind}.#{item.action_type}"),
        title: item.title_for(locale),
        path: path_for(item)
      )
    end

    def path_for(item)
      case item.product_kind
      when "expert_advisor"
        return unless item.subject.is_a?(ExpertAdvisor)

        dashboard_expert_advisor_path(item.subject, locale: locale)
      when "course"
        return unless item.subject.is_a?(Course)

        dashboard_course_path(item.subject, locale: locale)
      when "addon"
        return unless item.subject.is_a?(MarketplaceProduct)

        dashboard_marketplace_product_path(item.subject, locale: locale)
      end
    end
  end
end
