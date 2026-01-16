ActiveAdmin.register ManualTransaction do
  permit_params :user_id, :billing_plan_id, :amount_cents, :currency, :paid_at, :payment_method, :reference, :notes

  index do
    selectable_column
    id_column
    column :user
    column :billing_plan
    column :amount_cents do |transaction|
      number_to_currency(transaction.amount_cents.to_f / 100.0, unit: "$", precision: 2)
    end
    column :currency
    column :paid_at
    column :recorded_by_admin
    column :created_at
    actions
  end

  filter :user
  filter :billing_plan
  filter :paid_at
  filter :recorded_by_admin
  filter :created_at

  form do |f|
    f.inputs do
      f.input :user
      f.input :billing_plan, collection: BillingPlan.one_time.ordered
      f.input :amount_cents
      f.input :currency, as: :select, collection: ["usd"], include_blank: false
      f.input :paid_at
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
      params[:manual_transaction][:recorded_by_admin_id] = current_user.id
      super
    end
  end
end
