require "set"

module ProductReleases
  class VisibleItems
    def initialize(user:, release:, accessible_eas:, accessible_courses:, marketplace_available: false)
      @user = user
      @release = release
      @accessible_eas = Array(accessible_eas)
      @accessible_courses = Array(accessible_courses)
      @marketplace_available = marketplace_available
    end

    def call
      return [] unless user && release

      release.product_release_items.select do |item|
        case item.product_kind
        when "expert_advisor"
          accessible_ea_ids.include?(item.subject_id)
        when "course"
          accessible_course_ids.include?(item.subject_id)
        when "addon"
          marketplace_available && item.subject.is_a?(MarketplaceProduct)
        else
          false
        end
      end
    end

    private

    attr_reader :user, :release, :accessible_eas, :accessible_courses, :marketplace_available

    def accessible_ea_ids
      @accessible_ea_ids ||= accessible_eas.select(&:accessible).map { |entry| entry.expert_advisor.id }.to_set
    end

    def accessible_course_ids
      @accessible_course_ids ||= accessible_courses.select(&:accessible).map { |entry| entry.course.id }.to_set
    end
  end
end
