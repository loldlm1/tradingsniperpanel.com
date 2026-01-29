module Dashboard
  class SidebarRecentCourses
    def initialize(entries:, user:, limit: 5, active_course_slug: nil)
      @entries = Array(entries)
      @user = user
      @limit = limit
      @active_course_slug = active_course_slug.to_s.presence
    end

    def call
      recent_entries = entries.select { |entry| last_watched_by_course_id.key?(entry.course.id) }
      recent_sorted = recent_entries.sort_by { |entry| last_watched_by_course_id[entry.course.id].to_i }.reverse
      fallback_sorted = entries_without_watches.sort_by { |entry| published_timestamp(entry).to_i }.reverse
      list = (recent_sorted + fallback_sorted).uniq { |entry| entry.course.id }.first(limit)

      append_active(list)
    end

    private

    attr_reader :entries, :user, :limit, :active_course_slug

    def last_watched_by_course_id
      return @last_watched_by_course_id if defined?(@last_watched_by_course_id)
      return @last_watched_by_course_id = {} unless user

      @last_watched_by_course_id = CourseLessonProgress
        .joins(course_lesson: { course_module: :course })
        .where(user: user)
        .where.not(last_watched_at: nil)
        .group("courses.id")
        .maximum("course_lesson_progresses.last_watched_at")
    end

    def entries_without_watches
      entries.reject { |entry| last_watched_by_course_id.key?(entry.course.id) }
    end

    def published_timestamp(entry)
      entry.course.published_at || entry.course.created_at
    end

    def append_active(list)
      return list unless active_course_slug

      active_entry = entries.find { |entry| entry.course.slug.to_s == active_course_slug }
      return list unless active_entry
      return list if list.any? { |entry| entry.course.id == active_entry.course.id }

      list + [active_entry]
    end
  end
end
