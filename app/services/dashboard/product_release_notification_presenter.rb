module Dashboard
  class ProductReleaseNotificationPresenter
    include Rails.application.routes.url_helpers

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
      release.present?
    end

    def unread?
      present?
    end

    def release
      @release ||= candidate_releases.find { |candidate| visible_items_for(candidate).any? }
    end

    def items
      @items ||= visible_items_for(release).map { |item| build_item(item) }
    end

    def published_at_label
      return unless release

      I18n.l(release.published_at, format: :short_with_year, locale: locale)
    end

    def release_summary
      return I18n.t("dashboard.product_releases.empty") unless present?

      I18n.t("dashboard.product_releases.summary", count: items.size)
    end

    def dismiss_path
      return unless release

      dismiss_dashboard_product_release_path(release, locale: locale)
    end

    def default_url_options
      { locale: locale }
    end

    private

    attr_reader :user, :accessible_eas, :accessible_courses, :marketplace_available, :locale

    def candidate_releases
      ProductRelease.latest_first
                    .includes(product_release_items: :subject)
                    .where.not(id: user.product_release_dismissals.select(:product_release_id))
                    .limit(10)
    end

    def visible_items_for(candidate_release)
      return [] unless candidate_release

      ProductReleases::VisibleItems.new(
        user: user,
        release: candidate_release,
        accessible_eas: accessible_eas,
        accessible_courses: accessible_courses,
        marketplace_available: marketplace_available
      ).call
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
