ActiveAdmin.register PartnerPayoutRequest do
  permit_params :status, :payment_reference, :note

  actions :all, except: [:new, :create, :destroy]

  scope :all, default: true
  scope(:pending) { |scope| scope.pending }
  scope(:paid) { |scope| scope.paid }
  scope(:cancelled) { |scope| scope.cancelled }

  index do
    selectable_column
    id_column
    column :partner_profile
    column :partner do |request|
      request.partner_profile.user.email
    end
    column :status
    column :notification_status
    column(:total_cents) { |request| number_to_currency(request.total_cents.to_i / 100.0) }
    column :requested_at
    column :paid_at
    actions
  end

  filter :status, as: :select, collection: -> { PartnerPayoutRequest.statuses.keys }
  filter :notification_status, as: :select, collection: -> { PartnerPayoutRequest.notification_statuses.keys }
  filter :requested_at
  filter :paid_at
  filter :created_at

  show do
    attributes_table do
      row :id
      row :partner_profile
      row(:partner) { |request| request.partner_profile.user.email }
      row :status
      row :notification_status
      row :notification_sent_at
      row :notification_failed_at
      row :notification_failure_message
      row(:total_cents) { |request| number_to_currency(request.total_cents.to_i / 100.0) }
      row :requested_at
      row :paid_at
      row :payment_reference
      row :note
      row :created_at
      row :updated_at
    end

    panel t("active_admin.partner_payout_requests.sections.commissions") do
      table_for resource.partner_commissions.order(occurred_at: :desc) do
        column :id
        column(:referred_user) { |commission| commission.referred_user.email }
        column :commission_kind
        column :status
        column(:amount_cents) { |commission| number_to_currency(commission.amount_cents.to_i / 100.0) }
        column :occurred_at
      end
    end
  end

  form do |f|
    f.inputs t("active_admin.partner_payout_requests.sections.details") do
      f.input :status, as: :select, collection: PartnerPayoutRequest.statuses.keys
      f.input :payment_reference
      f.input :note
    end
    f.actions
  end

  controller do
    def update
      case payout_params[:status].to_s
      when "paid"
        resource.mark_paid!(payment_reference: payout_params[:payment_reference].presence)
        resource.update!(note: payout_params[:note]) if payout_params[:note].present?
      when "cancelled"
        resource.mark_cancelled!(note: payout_params[:note].presence)
        resource.update!(payment_reference: payout_params[:payment_reference].presence)
      else
        resource.update!(payment_reference: payout_params[:payment_reference], note: payout_params[:note])
      end

      redirect_to admin_partner_payout_request_path(resource), notice: t("active_admin.partner_payout_requests.updated")
    rescue StandardError => e
      flash.now[:alert] = e.message
      render :edit, status: :unprocessable_entity
    end

    private

    def payout_params
      params.require(:partner_payout_request).permit(:status, :payment_reference, :note)
    end
  end
end
