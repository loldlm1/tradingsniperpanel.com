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
                      .includes(:course_plan_entitlements, :billing_plans, course_modules: :course_lessons)
                      .ordered
      enrollment_map = enrollments_indexed
      current_tier = resolved_tier

      courses.map do |course|
        enrollment = enrollment_map[course.id]
        Entry.new(
          course: course,
          accessible: course.allowed_for_tier?(current_tier),
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
      return nil unless user.respond_to?(:pay_customers)
      return nil unless Pay::Customer.table_exists?

      customer = user.pay_customers.first
      subscription = customer&.subscriptions&.active&.order(created_at: :desc)&.first
      price_id = subscription&.processor_plan
      return nil if price_id.blank?

      plan = BillingPlan.for_price_id(price_id)
      return plan.tier if plan&.tier.present?

      price_key = Billing::PriceKeyResolver.key_for_price_id(price_id)
      price_key.to_s.split("_").first
    end

    def cta_plan_for(course)
      plans = course.billing_plans.subscription.active
      return if plans.empty?

      plans.min_by { |plan| [plan.sort_order.to_i, plan.amount_cents.to_i] }
    end
  end
end
