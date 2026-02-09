module Courses
  class AccessibleCourses
    Entry = Struct.new(
      :course,
      :accessible,
      :allowed_tiers,
      :cta_plan,
      :progress_percent,
      keyword_init: true
    )

    def initialize(user:, tier: nil)
      @user = user
      @tier = tier
    end

    def call
      return [] unless user

      courses = Course.published
                      .with_attached_cover_image
                      .includes(:course_plan_entitlements, :billing_plans, :tags, course_modules: :course_lessons)
                      .ordered
      enrollment_map = enrollments_indexed
      current_tier = resolved_tier
      privileged_full_access = Access::PrivilegedRolePolicy.full_access?(user)

      courses.map do |course|
        enrollment = enrollment_map[course.id]
        purchased_access = enrollment&.access_source_one_time?
        tier_access = course.allowed_for_tier?(current_tier)
        Entry.new(
          course: course,
          accessible: privileged_full_access || purchased_access || tier_access,
          allowed_tiers: course.subscription_tiers,
          cta_plan: cta_plan_for(course),
          progress_percent: enrollment&.progress_percent
        )
      end
    end

    private

    attr_reader :user, :tier

    def enrollments_indexed
      return {} unless user

      user.course_enrollments.index_by(&:course_id)
    end

    def resolved_tier
      return tier.to_s if tier.present?

      subscription = Billing::ActiveSubscriptionFinder.new(user: user).call.subscription
      Billing::SubscriptionPlanResolver.new(subscription: subscription).tier
    end

    def cta_plan_for(course)
      plans = course.billing_plans.subscription.active
      return if plans.empty?

      plans.min_by { |plan| [plan.sort_order.to_i, plan.amount_cents.to_i] }
    end
  end
end
