module Marketplace
  class Catalog
    Entry = Struct.new(
      :product,
      :plan,
      :purchased,
      :purchase,
      :price_display,
      :expert_advisors,
      :courses,
      :owned_expert_advisors,
      :owned_courses,
      :remaining_expert_advisors,
      :remaining_courses,
      keyword_init: true
    )

    def initialize(user:, scope: MarketplaceProduct)
      @user = user
      @scope = scope
    end

    def call
      purchase_map, purchased_ea_ids, purchased_course_ids = purchase_context

      product_scope.map do |product|
        build_entry(product, purchase_map, purchased_ea_ids, purchased_course_ids)
      end
    end

    def entry_for!(slug:)
      purchase_map, purchased_ea_ids, purchased_course_ids = purchase_context
      product = product_scope.find_by!(slug: slug)

      build_entry(product, purchase_map, purchased_ea_ids, purchased_course_ids)
    end

    private

    attr_reader :user, :scope

    def product_scope
      scope.active
           .joins(:billing_plan)
           .merge(BillingPlan.active)
           .ordered
           .includes(:billing_plan, image_attachment: :blob, billing_plan: [:expert_advisors, :courses])
    end

    def purchase_context
      purchases = purchases_for_user
      purchase_map = purchases.index_by(&:billing_plan_id)
      [purchase_map, purchased_ea_ids(purchases), purchased_course_ids(purchases)]
    end

    def purchases_for_user
      return MarketplacePurchase.none unless user

      MarketplacePurchase.where(user: user).includes(billing_plan: [:expert_advisors, :courses])
    end

    def purchased_ea_ids(purchases)
      purchases.flat_map { |purchase| purchase.billing_plan.expert_advisors.map(&:id) }.uniq
    end

    def purchased_course_ids(purchases)
      purchases.flat_map { |purchase| purchase.billing_plan.courses.map(&:id) }.uniq
    end

    def build_entry(product, purchase_map, purchased_ea_ids, purchased_course_ids)
      plan = product.billing_plan
      expert_advisors = sorted_expert_advisors(product.expert_advisors)
      courses = sorted_courses(product.courses)
      owned_expert_advisors = expert_advisors.select { |ea| purchased_ea_ids.include?(ea.id) }
      owned_courses = courses.select { |course| purchased_course_ids.include?(course.id) }

      Entry.new(
        product: product,
        plan: plan,
        purchased: purchase_map.key?(plan&.id),
        purchase: purchase_map[plan&.id],
        price_display: price_display(plan),
        expert_advisors: expert_advisors,
        courses: courses,
        owned_expert_advisors: owned_expert_advisors,
        owned_courses: owned_courses,
        remaining_expert_advisors: expert_advisors - owned_expert_advisors,
        remaining_courses: courses - owned_courses
      )
    end

    def sorted_expert_advisors(expert_advisors)
      expert_advisors.sort_by { |ea| [ea.tier_rank.to_i, ea.name.to_s] }
    end

    def sorted_courses(courses)
      courses.sort_by { |course| [course.position.to_i, course.title_en.to_s] }
    end

    def price_display(plan)
      return nil unless plan&.amount_cents

      ActionController::Base.helpers.number_to_currency(plan.amount_cents / 100.0, unit: "$", precision: 2)
    end
  end
end
