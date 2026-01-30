ActiveAdmin.register CoursePlanEntitlement do
  permit_params :billing_plan_id, :course_id

  controller do
    def scoped_collection
      super.includes(:billing_plan, :course)
    end
  end

  index do
    selectable_column
    id_column
    column :billing_plan
    column :course
    column :created_at
    actions
  end

  filter :billing_plan, as: :select, collection: -> { BillingPlan.ordered }
  filter :course
  filter :created_at

  form do |f|
    f.inputs t("active_admin.plan_entitlements.sections.details") do
      f.input :billing_plan, collection: BillingPlan.ordered.map { |plan| ["#{plan.name} (#{plan.key})", plan.id] }
      f.input :course, collection: Course.ordered.map { |course| [course.title_en, course.id] }
    end
    f.actions
  end
end
