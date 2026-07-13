ActiveAdmin.register ManualSubscription do
  actions :index, :show, :new, :create
  config.batch_actions = false

  permit_params :user_id, :user_lookup, :billing_plan_id, :granted_days, :payment_status, :amount_cents,
                :paid_at, :payment_method, :reference, :notes, :request_id

  collection_action :user_search, method: :get do
    term = params[:q].to_s.strip.downcase
    return render json: [] if term.length < 2

    escaped_term = ActiveRecord::Base.sanitize_sql_like(term)
    users = User.where("LOWER(email) LIKE ?", "#{escaped_term}%")
                .limit(20)
                .select(:id, :email, :name)

    render json: users.map { |user| { id: user.id, label: [ user.email, user.name.presence ].compact.join(" - "), value: user.email } }
  end

  member_action :revoke, method: :post do
    ManualSubscriptions::Revoke.new(
      subscription: resource,
      actor: current_user,
      request_id: params[:request_id]
    ).call
    redirect_to resource_path(resource), notice: t("active_admin.manual_subscriptions.revoked")
  rescue ManualSubscriptions::Revoke::Unauthorized
    head :forbidden
  rescue ArgumentError,
         ManualSubscriptions::Revoke::IdempotencyConflict,
         ManualSubscriptions::Revoke::NotRevocable,
         ActiveRecord::RecordInvalid => e
    redirect_to resource_path(resource),
                alert: t("active_admin.manual_subscriptions.revoke_failed", message: e.message)
  end

  action_item :revoke, only: :show, if: proc { resource.revocable? } do
    link_to t("active_admin.manual_subscriptions.actions.revoke"),
            revoke_admin_manual_subscription_path(resource, request_id: SecureRandom.uuid),
            method: :post,
            data: {
              confirm: t(
                "active_admin.manual_subscriptions.revoke_confirm",
                email: resource.user.email,
                ends_at: I18n.l(resource.ends_at, format: :long)
              )
            }
  end

  index do
    id_column
    column :user
    column :billing_plan
    column :granted_days
    column :payment_status
    column :amount_cents do |subscription|
      admin_currency_from_cents(subscription.amount_cents, currency: subscription.currency)
    end
    column :currency
    column :paid_at
    column :starts_at
    column :ends_at
    column :status
    column :superseded_at
    column :recorded_by_admin
    column :created_at
    actions defaults: true do |subscription|
      if subscription.revocable?
        item t("active_admin.manual_subscriptions.actions.revoke"),
             revoke_admin_manual_subscription_path(subscription, request_id: SecureRandom.uuid),
             method: :post,
             data: {
               confirm: t(
                 "active_admin.manual_subscriptions.revoke_confirm",
                 email: subscription.user.email,
                 ends_at: I18n.l(subscription.ends_at, format: :long)
               )
             }
      end
    end
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
    f.inputs t("active_admin.manual_subscriptions.sections.access") do
      f.input :request_id, as: :hidden, input_html: { value: SecureRandom.uuid }
      f.input :user_id, as: :hidden
      f.input :user_lookup,
              as: :string,
              label: t("active_admin.manual_subscriptions.user_lookup.label"),
              hint: t("active_admin.manual_subscriptions.user_lookup.hint"),
              input_html: {
                type: "search",
                autocomplete: "off",
                class: "manual-subscription-user-search-input",
                data: {
                  manual_subscription_user_search: true,
                  search_url: user_search_admin_manual_subscriptions_path,
                  user_id_input: "manual_subscription_user_id"
                }
              }
      f.input :billing_plan,
              collection: BillingPlan.purchasable
                                     .joins(:expert_advisors)
                                     .where(tier: ManualSubscriptions::Grant::PANDORA_TIER)
                                     .where(expert_advisors: { ea_id: ManualSubscriptions::Grant::PANDORA_EA_ID })
                                     .distinct
                                     .ordered
      f.input :granted_days, input_html: { min: 1, max: ManualSubscriptions::Grant::MAX_GRANTED_DAYS }
    end
    f.inputs t("active_admin.manual_subscriptions.sections.payment") do
      f.input :payment_status,
              as: :select,
              collection: ManualSubscription.payment_statuses.keys,
              include_blank: t("active_admin.manual_subscriptions.automatic"),
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
        :user_lookup,
        :billing_plan_id,
        :granted_days,
        :payment_status,
        :amount_cents,
        :paid_at,
        :payment_method,
        :reference,
        :notes,
        :request_id
      )
      subscription = ManualSubscriptions::Grant.new(
        user: resolve_user(attributes),
        billing_plan: BillingPlan.find_by(id: attributes[:billing_plan_id]),
        granted_days: attributes[:granted_days],
        recorded_by_admin: current_user,
        request_id: attributes[:request_id],
        payment_status: attributes[:payment_status].presence,
        amount_cents: attributes[:amount_cents].presence,
        paid_at: attributes[:paid_at].presence,
        payment_method: attributes[:payment_method],
        reference: attributes[:reference],
        notes: attributes[:notes]
      ).call

      redirect_to resource_path(subscription), notice: t("active_admin.manual_subscriptions.granted")
    rescue ArgumentError, ActiveRecord::RecordInvalid, ManualSubscriptions::Grant::IdempotencyConflict => e
      redirect_to new_resource_path, alert: e.message
    end

    private

    def resolve_user(attributes)
      lookup = attributes[:user_lookup].to_s.strip.downcase
      return User.find_by("LOWER(email) = ?", lookup) if lookup.present?

      User.find_by(id: attributes[:user_id])
    end
  end
end
