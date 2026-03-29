module Dashboard
  class ProductReleasesController < ApplicationController
    layout "dashboard"
    before_action :authenticate_user!
    before_action :set_accessible_expert_advisors
    before_action :set_accessible_courses
    before_action :set_marketplace_availability

    def dismiss
      release = ProductRelease.find(params[:id])
      visible_items = ProductReleases::VisibleItems.new(
        user: current_user,
        release: release,
        accessible_eas: @accessible_eas,
        accessible_courses: @accessible_courses,
        marketplace_available: @marketplace_available
      ).call

      head :not_found and return if visible_items.empty?

      current_user.product_release_dismissals.find_or_create_by!(product_release: release) do |dismissal|
        dismissal.dismissed_at = Time.current
      end

      redirect_back fallback_location: dashboard_path(locale: I18n.locale), notice: t("dashboard.product_releases.dismissed")
    end
  end
end
