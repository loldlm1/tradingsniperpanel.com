module Dashboard
  class ProductReleasesController < ApplicationController
    layout "dashboard"
    before_action :authenticate_user!
    before_action :set_accessible_expert_advisors
    before_action :set_accessible_courses
    before_action :set_marketplace_availability

    def clear
      releases = unread_visible_releases
      head :not_found and return if releases.empty?

      dismissed_at = Time.current
      releases.each do |entry|
        current_user.product_release_dismissals.find_or_create_by!(product_release: entry.release) do |dismissal|
          dismissal.dismissed_at = dismissed_at
        end
      end

      redirect_back fallback_location: dashboard_path(locale: I18n.locale), notice: t("dashboard.product_releases.cleared")
    end

    def dismiss
      clear
    end

    private

    def unread_visible_releases
      ProductReleases::UnreadVisibleReleases.new(
        user: current_user,
        accessible_eas: @accessible_eas,
        accessible_courses: @accessible_courses,
        marketplace_available: @marketplace_available
      ).call
    end
  end
end
