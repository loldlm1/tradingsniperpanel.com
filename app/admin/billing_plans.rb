ActiveAdmin.register BillingPlan do
  permit_params :key, :name, :description, :kind, :tier, :interval, :interval_count, :amount_cents,
                :currency, :active, :sort_order, :stripe_product_id, :stripe_price_id, :metadata

  controller do
    def create
      result = Admin::BillingPlanUpsert.new(attributes: plan_params).call

      if result.ok?
        redirect_to admin_billing_plan_path(result.plan), notice: t("active_admin.billing_plans.created")
      else
        @billing_plan = result.plan
        flash.now[:alert] = result.errors.to_sentence
        render :new
      end
    end

    def update
      result = Admin::BillingPlanUpsert.new(plan: resource, attributes: plan_params).call

      if result.ok?
        redirect_to admin_billing_plan_path(result.plan), notice: t("active_admin.billing_plans.updated")
      else
        @billing_plan = result.plan
        flash.now[:alert] = result.errors.to_sentence
        render :edit
      end
    end

    private

    def plan_params
      params.require(:billing_plan).permit(
        :key,
        :name,
        :description,
        :kind,
        :tier,
        :interval,
        :interval_count,
        :amount_cents,
        :currency,
        :active,
        :sort_order,
        :stripe_product_id,
        :stripe_price_id,
        :metadata
      )
    end
  end

  index do
    selectable_column
    id_column
    column :key
    column :name
    column :kind
    column :tier
    column :interval
    column :interval_count
    column :amount_cents do |plan|
      admin_currency_from_cents(plan.amount_cents)
    end
    column :currency
    column :active
    column :sort_order
    column :stripe_product_id
    column :stripe_price_id
    actions
  end

  filter :key
  filter :name
  filter :kind, as: :select, collection: BillingPlan.kinds.keys
  filter :tier
  filter :interval, as: :select, collection: BillingPlan::INTERVALS
  filter :active
  filter :created_at

  form do |f|
    f.inputs t("active_admin.billing_plans.sections.details") do
      if f.object.persisted?
        f.input :key, input_html: { disabled: true }
      else
        f.input :key, hint: t("active_admin.billing_plans.hints.key")
      end
      f.input :name
      f.input :description
      f.input :kind, as: :select, collection: BillingPlan.kinds.keys
      f.input :tier
      f.input :interval, as: :select, collection: BillingPlan::INTERVALS, include_blank: true
      f.input :interval_count
      f.input :amount_cents
      f.input :currency, as: :select, collection: [["USD", "usd"]]
      f.input :active
      f.input :sort_order
    end

    f.inputs t("active_admin.billing_plans.sections.stripe") do
      f.input :stripe_product_id
      f.input :stripe_price_id
    end

    f.inputs t("active_admin.billing_plans.sections.metadata") do
      f.input :metadata, as: :text, input_html: { rows: 6 }, hint: t("active_admin.billing_plans.hints.metadata")
    end

    f.actions
  end
end
