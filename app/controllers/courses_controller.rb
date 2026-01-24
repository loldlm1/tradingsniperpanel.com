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
      page: params[:page],
      items: 8
    )
  end

  def show
    @course = @course_entry&.course || Course.published.find_by!(slug: params[:id])
    @course_modules = @course.course_modules.includes(:course_lessons).ordered
  end

  private

  def set_course_entry
    @course_entry = (@accessible_courses || []).find { |entry| entry.course.slug == params[:id] }
  end
end
