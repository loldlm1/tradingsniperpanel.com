ActiveAdmin.register RevenueSplitPayout do
  permit_params :period_key, :as_of, :notes

  config.clear_action_items!

  action_item :new, only: :index do
    if master_admin?
      link_to t("active_admin.new_model", model: RevenueSplitPayout.model_name.human), new_admin_revenue_split_payout_path
    end
  end

  action_item :edit, only: :show do
    if master_admin?
      link_to t("active_admin.edit_model", model: RevenueSplitPayout.model_name.human), edit_admin_revenue_split_payout_path(resource)
    end
  end

  index do
    selectable_column
    id_column
    column :period_key
    column :starts_at
    column :ends_at
    column :status
    column :paid_at
    column :paid_by_admin
    column :net_cents do |payout|
      admin_currency_from_cents(payout.net_cents)
    end
    column :us_cents do |payout|
      admin_currency_from_cents(payout.us_cents)
    end
    column :client_cents do |payout|
      admin_currency_from_cents(payout.client_cents)
    end
    column :created_at
    actions defaults: false do |payout|
      item t("active_admin.view"), admin_revenue_split_payout_path(payout)
      if master_admin?
        item t("active_admin.edit"), edit_admin_revenue_split_payout_path(payout)
      end
    end
  end

  filter :period_key, as: :select, collection: Admin::Analytics::PeriodResolver::PERIOD_KEYS
  filter :status
  filter :starts_at
  filter :ends_at
  filter :paid_at
  filter :paid_by_admin
  filter :created_at

  form do |f|
    f.inputs do
      if f.object.persisted?
        f.input :period_key, input_html: { disabled: true }
        f.input :starts_at, input_html: { disabled: true }
        f.input :ends_at, input_html: { disabled: true }
        f.input :net_cents, input_html: { disabled: true }
        f.input :us_cents, input_html: { disabled: true }
        f.input :client_cents, input_html: { disabled: true }
        f.input :paid_at, input_html: { disabled: true }
        f.input :paid_by_admin, input_html: { disabled: true }
        f.input :notes
      else
        f.input :period_key, as: :select, collection: Admin::Analytics::PeriodResolver::PERIOD_KEYS
        f.input :as_of, as: :date_picker
        f.input :notes
      end
    end
    f.actions
  end

  controller do
    before_action :require_master_admin!, only: %i[new create edit update destroy]

    def create
      result = Admin::Analytics::PayoutRecorder.new(
        period_key: payout_params[:period_key],
        as_of: payout_params[:as_of],
        actor: current_user,
        notes: payout_params[:notes]
      ).call

      if result.ok?
        redirect_to admin_revenue_split_payout_path(result.payout), notice: t("active_admin.payouts.created")
      else
        @revenue_split_payout = RevenueSplitPayout.new(payout_params)
        flash.now[:alert] = result.errors.join(", ")
        render :new
      end
    end

    def update
      if resource.update(payout_update_params)
        redirect_to admin_revenue_split_payout_path(resource), notice: t("active_admin.payouts.updated")
      else
        flash.now[:alert] = resource.errors.full_messages.to_sentence
        render :edit
      end
    end

    private

    def payout_params
      params.require(:revenue_split_payout).permit(:period_key, :as_of, :notes)
    end

    def payout_update_params
      params.require(:revenue_split_payout).permit(:notes)
    end

    def require_master_admin!
      return if master_admin?

      redirect_to admin_revenue_split_payouts_path, alert: t("active_admin.users.role_forbidden")
    end
  end
end
