ActiveAdmin.register ManualSubscription do
  permit_params :user_id, :billing_plan_id, :amount_cents, :currency, :paid_at, :starts_at, :ends_at,
                :status, :payment_method, :reference, :notes

  index do
    selectable_column
    id_column
    column :user
    column :billing_plan
    column :amount_cents do |subscription|
      number_to_currency(subscription.amount_cents.to_f / 100.0, unit: "$", precision: 2)
    end
    column :currency
    column :paid_at
    column :starts_at
    column :ends_at
    column :status
    column :recorded_by_admin
    column :created_at
    actions
  end

  filter :user
  filter :billing_plan
  filter :status
  filter :paid_at
  filter :ends_at
  filter :recorded_by_admin
  filter :created_at

  form do |f|
    f.inputs do
      f.input :user
      f.input :billing_plan, collection: BillingPlan.subscription.ordered
      f.input :amount_cents
      f.input :currency, as: :select, collection: ["usd"], include_blank: false
      f.input :paid_at
      f.input :starts_at
      f.input :ends_at
      f.input :status, as: :select, collection: ManualSubscription.statuses.keys
      f.input :payment_method
      f.input :reference
      f.input :notes
    end
    f.actions
  end

  controller do
    def scoped_collection
      super.includes(:user, :billing_plan, :recorded_by_admin)
    end

    def create
      params[:manual_subscription][:recorded_by_admin_id] = current_user.id
      super
    end
  end
end
