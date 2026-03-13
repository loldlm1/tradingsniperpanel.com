ActiveAdmin.register PartnerProfile do
  permit_params :user_id, :active, :referral_code, :discount_percent, :commission_percent, :payout_mode

  actions :all, except: [:destroy]

  scope :all, default: true
  scope(:active) { |scope| scope.where(active: true) }
  scope(:inactive) { |scope| scope.where(active: false) }

  member_action :activate, method: :post do
    resource.update!(active: true)
    redirect_to admin_partner_profile_path(resource), notice: t("active_admin.partner_profiles.activated")
  rescue StandardError => e
    redirect_to admin_partner_profile_path(resource), alert: e.message
  end

  member_action :deactivate, method: :post do
    resource.update!(active: false)
    redirect_to admin_partner_profile_path(resource), notice: t("active_admin.partner_profiles.deactivated")
  rescue StandardError => e
    redirect_to admin_partner_profile_path(resource), alert: e.message
  end

  action_item :activate, only: :show, if: proc { !resource.active? } do
    link_to t("active_admin.partner_profiles.actions.activate"), activate_admin_partner_profile_path(resource), method: :post
  end

  action_item :deactivate, only: :show, if: proc { resource.active? } do
    link_to t("active_admin.partner_profiles.actions.deactivate"), deactivate_admin_partner_profile_path(resource), method: :post
  end

  index do
    selectable_column
    id_column
    column :user
    column :active do |profile|
      status_tag(profile.active? ? "active" : "inactive")
    end
    column :referral_code
    column :discount_percent
    column :commission_percent
    column :payout_mode
    column :started_at
    actions defaults: true do |profile|
      if profile.active?
        item t("active_admin.partner_profiles.actions.deactivate"), deactivate_admin_partner_profile_path(profile), method: :post
      else
        item t("active_admin.partner_profiles.actions.activate"), activate_admin_partner_profile_path(profile), method: :post
      end
    end
  end

  filter :user_email, as: :string
  filter :active
  filter :referral_code
  filter :discount_percent
  filter :commission_percent
  filter :payout_mode, as: :select, collection: -> { PartnerProfile.payout_modes.keys }
  filter :started_at
  filter :created_at

  show do
    attributes_table do
      row :id
      row :user
      row(:active) { |profile| status_tag(profile.active? ? "active" : "inactive") }
      row :referral_code
      row :discount_percent
      row :commission_percent
      row :payout_mode
      row :stripe_coupon_id
      row :started_at
      row :created_at
      row :updated_at
    end

    panel t("active_admin.partner_profiles.sections.payout_requests") do
      table_for resource.partner_payout_requests.order(created_at: :desc).limit(10) do
        column :id do |request|
          link_to request.id, admin_partner_payout_request_path(request)
        end
        column :status
        column :notification_status
        column(:total_cents) { |request| number_to_currency(request.total_cents.to_i / 100.0) }
        column :requested_at
        column :paid_at
      end
    end
  end

  form do |f|
    f.inputs t("active_admin.partner_profiles.sections.details") do
      if f.object.persisted?
        f.input :user, input_html: { disabled: true }
      else
        f.input :user, collection: User.order(:email).map { |user| ["#{user.email} (##{user.id})", user.id] }
      end
      f.input :active
      f.input :referral_code, hint: t("active_admin.partner_profiles.hints.referral_code")
      f.input :discount_percent
      f.input :commission_percent
      f.input :payout_mode, as: :select, collection: PartnerProfile.payout_modes.keys
    end
    f.actions
  end

  controller do
    def create
      super do |success, failure|
        success.html { redirect_to admin_partner_profile_path(resource), notice: t("active_admin.partner_profiles.created") }
        failure.html { flash.now[:alert] = resource.errors.full_messages.to_sentence }
      end
    end

    def update
      super do |success, failure|
        success.html { redirect_to admin_partner_profile_path(resource), notice: t("active_admin.partner_profiles.updated") }
        failure.html { flash.now[:alert] = resource.errors.full_messages.to_sentence }
      end
    end
  end
end
