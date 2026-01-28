module Courses
  class ShowPresenter
    LessonItem = Struct.new(
      :lesson,
      :index,
      :title,
      :duration_label,
      :url,
      :accessible,
      :completed,
      keyword_init: true
    )

    ModuleCard = Struct.new(
      :course_module,
      :index,
      :title,
      :summary,
      :lessons_count,
      :progress_percent,
      :lessons,
      keyword_init: true
    )

    def initialize(course:, entry:, course_modules:, enrollment:, lesson_progresses:, unlock_url:, locale:)
      @course = course
      @entry = entry
      @course_modules = course_modules
      @enrollment = enrollment
      @unlock_url = unlock_url
      @locale = locale
      @lesson_progresses = index_progresses(lesson_progresses)
    end

    attr_reader :course, :entry, :course_modules, :enrollment, :unlock_url, :locale

    def title
      course.title_for(locale)
    end

    def category_label
      I18n.t("dashboard.courses.categories.#{course.category}", default: course.category.to_s.humanize)
    end

    def status_label
      I18n.t("dashboard.courses.status.#{course.status}", default: course.status.to_s.humanize)
    end

    def status_badge_class
      case course.status
      when "published"
        "bg-emerald-100 text-emerald-700 dark:bg-emerald-500/20 dark:text-emerald-300"
      when "draft"
        "bg-amber-100 text-amber-700 dark:bg-amber-500/20 dark:text-amber-300"
      else
        "bg-gray-100 text-gray-700 dark:bg-gray-700/60 dark:text-gray-200"
      end
    end

    def access_state
      return :free if course.free_access?
      return :unlocked if accessible?

      :locked
    end

    def access_badge_label
      I18n.t("dashboard.courses.access_badges.#{access_state}")
    end

    def access_badge_class
      case access_state
      when :free
        "bg-emerald-100 text-emerald-700 dark:bg-emerald-500/20 dark:text-emerald-300"
      when :unlocked
        "bg-violet-100 text-violet-700 dark:bg-violet-500/20 dark:text-violet-300"
      else
        "bg-gray-100 text-gray-700 dark:bg-gray-700/60 dark:text-gray-200"
      end
    end

    def summary_text
      @summary_text ||= course.summary_for(locale).presence || course.description_for(locale)
    end

    def outcomes_text
      text = course.description_for(locale).presence
      return if text.blank? || text == summary_text

      text
    end

    def modules_count
      course_modules.size
    end

    def lessons_count
      @lessons_count ||= course_modules.sum { |course_module| course_module.course_lessons.size }
    end

    def total_duration_seconds
      @total_duration_seconds ||= course_modules.sum do |course_module|
        course_module.course_lessons.sum { |lesson| lesson.duration_seconds.to_i }
      end
    end

    def course_progress_percent
      stored = enrollment&.progress_percent || entry&.progress_percent
      return stored if stored.present?

      total = lessons_count
      return 0 if total <= 0

      completed = lesson_progresses.count { |_id, progress| progress.completed? }
      ((completed.to_f / total) * 100).round
    end

    def course_progress_percent_label
      value = course_progress_percent
      value = 0 if value.blank?
      value
    end

    def course_access_label
      accessible? ? I18n.t("dashboard.courses.access_granted") : I18n.t("dashboard.courses.access_locked")
    end

    def access_source_label
      return I18n.t("dashboard.courses.access_source.one_time") if enrollment&.access_source_one_time?
      return I18n.t("dashboard.courses.access_source.subscription") if accessible?

      I18n.t("dashboard.courses.access_source.locked")
    end

    def resume_lesson
      enrollment&.last_lesson || last_watched_lesson
    end

    def resume_url
      return unless accessible?

      lesson = resume_lesson
      return unless lesson

      Rails.application.routes.url_helpers.dashboard_course_lesson_path(course, lesson, locale: locale)
    end

    def module_cards
      @module_cards ||= course_modules.each_with_index.map do |course_module, index|
        lessons = ordered_lessons(course_module)
        ModuleCard.new(
          course_module:,
          index: index + 1,
          title: course_module.title_for(locale),
          summary: course_module.summary_for(locale),
          lessons_count: lessons.size,
          progress_percent: module_progress_percent(course_module),
          lessons: lesson_items(lessons)
        )
      end
    end

    def module_progress_items
      module_cards.map do |card|
        {
          title: card.title,
          percent: card.progress_percent
        }
      end
    end

    def accessible?
      entry&.accessible || course.free_access?
    end

    private

    attr_reader :lesson_progresses

    def index_progresses(progresses)
      return {} if progresses.blank?

      progresses.each_with_object({}) do |progress, acc|
        acc[progress.course_lesson_id] = progress
      end
    end

    def ordered_lessons(course_module)
      course_module.course_lessons.sort_by(&:position)
    end

    def lesson_items(lessons)
      lessons.each_with_index.map do |lesson, index|
        LessonItem.new(
          lesson:,
          index: index + 1,
          title: lesson.title_for(locale),
          duration_label: ApplicationController.helpers.format_duration(lesson.duration_seconds),
          url: lesson_url(lesson),
          accessible: accessible?,
          completed: lesson_completed?(lesson)
        )
      end
    end

    def lesson_completed?(lesson)
      progress = lesson_progresses[lesson.id]
      progress&.completed?
    end

    def module_progress_percent(course_module)
      lessons = course_module.course_lessons
      total = lessons.size
      return 0 if total <= 0

      completed = lessons.count { |lesson| lesson_completed?(lesson) }
      percent = ((completed.to_f / total) * 100).round
      [percent, 100].min
    end

    def lesson_url(lesson)
      return unless accessible?

      Rails.application.routes.url_helpers.dashboard_course_lesson_path(course, lesson, locale: locale)
    end

    def last_watched_lesson
      return if lesson_progresses.empty?

      last_progress = lesson_progresses.values.compact.max_by { |progress| progress.last_watched_at.to_i }
      last_progress&.course_lesson
    end
  end
end
