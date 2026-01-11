module Courses
  class ProgressTracker
    Result = Struct.new(:progress, :enrollment, :completed, keyword_init: true)

    def initialize(user:, lesson:, progress_seconds:, completed: false)
      @user = user
      @lesson = lesson
      @progress_seconds = progress_seconds.to_i
      @completed = ActiveModel::Type::Boolean.new.cast(completed)
    end

    def call
      return Result.new(progress: nil, enrollment: nil, completed: false) unless user && lesson

      progress = CourseLessonProgress.find_or_initialize_by(user: user, course_lesson: lesson)
      was_completed = progress.completed?

      progress.progress_seconds = [progress.progress_seconds.to_i, clamped_seconds].max
      progress.last_watched_at = Time.current

      if completed?(progress.progress_seconds)
        progress.status = "completed"
        progress.completed_at ||= Time.current
      end

      progress.save!

      enrollment = CourseEnrollment.find_or_initialize_by(user: user, course: lesson.course)
      enrollment.started_at ||= Time.current
      enrollment.last_lesson = lesson

      if progress.completed? && !was_completed
        update_enrollment_progress(enrollment)
      end

      enrollment.save!

      Result.new(progress: progress, enrollment: enrollment, completed: progress.completed?)
    end

    private

    attr_reader :user, :lesson, :progress_seconds, :completed

    def clamped_seconds
      duration = lesson.duration_seconds.to_i
      return progress_seconds if duration <= 0

      [progress_seconds, duration].min
    end

    def completed?(seconds)
      return true if completed

      duration = lesson.duration_seconds.to_i
      return false if duration <= 0

      seconds.to_f / duration >= 0.8
    end

    def update_enrollment_progress(enrollment)
      course = lesson.course
      total_lessons = course.course_lessons.count
      return if total_lessons.zero?

      completed_count = CourseLessonProgress
                        .where(user: user, status: "completed", course_lesson_id: course.course_lessons.select(:id))
                        .count

      percent = ((completed_count.to_f / total_lessons) * 100).round
      enrollment.progress_percent = [percent, 100].min
      enrollment.completed_at ||= Time.current if enrollment.progress_percent >= 100
    end
  end
end
