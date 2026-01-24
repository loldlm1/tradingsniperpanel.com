class CoursesController < ApplicationController
  layout "dashboard"
  before_action :authenticate_user!
  before_action :set_course_entry, only: [:show]

  def index
    @filter_query = params[:q].to_s.strip
    @filter_tag = params[:tag].to_s.strip
    @index_presenter = Courses::IndexPresenter.new(
      entries: @accessible_courses || [],
      locale: I18n.locale,
      marketplace_available: @marketplace_available,
      page: params[:page],
      items: 8
    )
  end

  def show
    @course = @course_entry&.course || Course.published.find_by!(slug: params[:id])
    @course_modules = @course.course_modules.includes(:course_lessons).ordered
    @unlock_url = unlock_url_for(@course_entry, @course)
  end

  private

  def set_course_entry
    @course_entry = (@accessible_courses || []).find { |entry| entry.course.slug == params[:id] }
  end

  def unlock_url_for(entry, course)
    return nil if entry&.accessible || course.free_access?

    if @marketplace_available
      product = MarketplaceProduct.active
                                   .joins(billing_plan: :course_plan_entitlements)
                                   .where(course_plan_entitlements: { course_id: course.id })
                                   .order(:sort_order)
                                   .first
      return dashboard_marketplace_product_path(product, locale: I18n.locale) if product.present?
    end

    plan = entry&.cta_plan
    return nil if plan.blank?

    dashboard_plans_path(price_key: plan.key, locale: I18n.locale)
  end
end
