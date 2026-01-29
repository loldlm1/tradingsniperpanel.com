ActiveAdmin.register BillingPlanEntitlement do
  permit_params :billing_plan_id, :expert_advisor_id

  controller do
    before_action :require_master_admin!, only: %i[new create edit update destroy]

    def scoped_collection
      super.includes(:billing_plan, :expert_advisor)
    end

    private

    def require_master_admin!
      return if master_admin?

      redirect_to admin_billing_plan_entitlements_path, alert: t("active_admin.users.role_forbidden")
    end
  end

  index do
    selectable_column
    id_column
    column :billing_plan
    column :expert_advisor
    column :created_at
    actions
  end

  filter :billing_plan, as: :select, collection: -> { BillingPlan.ordered }
  filter :expert_advisor
  filter :created_at

  form do |f|
    f.inputs t("active_admin.plan_entitlements.sections.details") do
      f.input :billing_plan, collection: BillingPlan.ordered.map { |plan| ["#{plan.name} (#{plan.key})", plan.id] }
      f.input :expert_advisor, collection: ExpertAdvisor.ordered_by_rank.map { |ea| [ea.name, ea.id] }
    end
    f.actions
  end
end
