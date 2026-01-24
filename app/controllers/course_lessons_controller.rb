class CourseLessonsController < ApplicationController
  layout "dashboard"
  before_action :authenticate_user!
  before_action :set_course_entry
  before_action :set_course_lesson
  before_action :ensure_access!
  before_action :set_markdown, only: [:show]
  before_action :set_playback_url, only: [:show]

  def show; end

  def update_progress
    tracker = Courses::ProgressTracker.new(
      user: current_user,
      lesson: @lesson,
      progress_seconds: progress_params[:progress_seconds],
      completed: progress_params[:completed]
    ).call

    render json: {
      ok: true,
      completed: tracker.completed,
      progress_percent: tracker.enrollment&.progress_percent
    }
  end

  private

  def set_course_entry
    @course_entry = (@accessible_courses || []).find { |entry| entry.course.slug == params[:course_id] }
    @course = @course_entry&.course || Course.published.find_by(slug: params[:course_id])
    return if @course.present?

    redirect_to dashboard_courses_path(locale: I18n.locale), alert: t("dashboard.courses.access_locked")
    return
  end

  def set_course_lesson
    return unless @course

    @lesson = CourseLesson.joins(:course_module).includes(:course_module)
                          .find_by(id: params[:id], course_modules: { course_id: @course.id })
    if @lesson.blank?
      redirect_to dashboard_course_path(@course, locale: I18n.locale), alert: t("dashboard.courses.access_locked")
      return
    end

    @course_module = @lesson.course_module
  end

  def ensure_access!
    return if @course_entry&.accessible
    return if @course.free_access?

    redirect_to dashboard_course_path(@course, locale: I18n.locale), alert: t("dashboard.courses.access_locked")
  end

  def set_markdown
    markdown = @lesson.body_markdown_for(I18n.locale)
    @markdown_html = markdown.present? ? MarkdownRenderer.render(markdown) : nil
  end

  def set_playback_url
    @playback_url = Courses::PlaybackUrlSigner.new(stream_uid: @lesson.stream_uid).call
  end

  def progress_params
    params.permit(:progress_seconds, :completed)
  end
end
