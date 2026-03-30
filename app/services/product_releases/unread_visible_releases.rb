module ProductReleases
  class UnreadVisibleReleases
    Entry = Struct.new(:release, :items, keyword_init: true)

    def initialize(user:, accessible_eas:, accessible_courses:, marketplace_available: false)
      @user = user
      @accessible_eas = Array(accessible_eas)
      @accessible_courses = Array(accessible_courses)
      @marketplace_available = marketplace_available
    end

    def call
      return [] unless user

      unread_releases.filter_map do |release|
        items = visible_items_for(release)
        next if items.empty?

        Entry.new(release:, items:)
      end
    end

    private

    attr_reader :user, :accessible_eas, :accessible_courses, :marketplace_available

    def unread_releases
      ProductRelease.latest_first
                    .includes(product_release_items: :subject)
                    .where.not(id: user.product_release_dismissals.select(:product_release_id))
    end

    def visible_items_for(release)
      ProductReleases::VisibleItems.new(
        user: user,
        release: release,
        accessible_eas: accessible_eas,
        accessible_courses: accessible_courses,
        marketplace_available: marketplace_available
      ).call
    end
  end
end
