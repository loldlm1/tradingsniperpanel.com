ActiveAdmin.register ManualSubscription do
  actions :index, :show, :new, :create

  permit_params :user_id, :billing_plan_id, :granted_days, :payment_status, :amount_cents,
                :paid_at, :payment_method, :reference, :notes

  index do
    selectable_column
    id_column
    column :user
    column :billing_plan
    column :granted_days
    column :payment_status
    column :amount_cents do |subscription|
      number_to_currency(subscription.amount_cents.to_d / 100, unit: "$", precision: 2)
    end
    column :currency
    column :paid_at
    column :starts_at
    column :ends_at
    column :status
    column :superseded_at
    column :recorded_by_admin
    column :created_at
    actions
  end

  filter :user
  filter :billing_plan
  filter :status
  filter :payment_status
  filter :granted_days
  filter :paid_at
  filter :ends_at
  filter :superseded_at
  filter :recorded_by_admin
  filter :created_at

  form do |f|
    f.inputs "Manual Pandora access" do
      f.input :user
      f.input :billing_plan,
              collection: BillingPlan.subscription.active
                                     .joins(:expert_advisors)
                                     .where(tier: ManualSubscriptions::Grant::PANDORA_TIER)
                                     .where(expert_advisors: { ea_id: ManualSubscriptions::Grant::PANDORA_EA_ID })
                                     .distinct
                                     .ordered
      f.input :granted_days, input_html: { min: 1, max: ManualSubscriptions::Grant::MAX_GRANTED_DAYS }
    end
    f.inputs "Optional payment details" do
      f.input :payment_status,
              as: :select,
              collection: ManualSubscription.payment_statuses.keys,
              include_blank: "Automatic",
              selected: nil
      f.input :amount_cents
      f.input :paid_at, as: :string, required: false, input_html: { type: "datetime-local" }
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
      attributes = params.require(:manual_subscription).permit(
        :user_id,
        :billing_plan_id,
        :granted_days,
        :payment_status,
        :amount_cents,
        :paid_at,
        :payment_method,
        :reference,
        :notes
      )
      subscription = ManualSubscriptions::Grant.new(
        user: User.find_by(id: attributes[:user_id]),
        billing_plan: BillingPlan.find_by(id: attributes[:billing_plan_id]),
        granted_days: attributes[:granted_days],
        recorded_by_admin: current_user,
        payment_status: attributes[:payment_status].presence,
        amount_cents: attributes[:amount_cents].presence,
        paid_at: attributes[:paid_at].presence,
        payment_method: attributes[:payment_method],
        reference: attributes[:reference],
        notes: attributes[:notes]
      ).call

      redirect_to resource_path(subscription), notice: "Manual Pandora access granted."
    rescue ArgumentError, ActiveRecord::RecordInvalid => e
      redirect_to new_resource_path, alert: e.message
    end
  end
end
