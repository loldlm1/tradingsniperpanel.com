ActiveAdmin.register User do
  permit_params :email, :password, :password_confirmation, :name, :role, :preferred_locale, :time_zone

  controller do
    before_action :restrict_master_admin_access, only: %i[show edit update destroy]
    before_action :clear_blank_passwords, only: :update

    def scoped_collection
      role_guard.visible_scope(super)
    end

    def create
      unless role_guard.allow_role_change?(record: nil, new_role: params.dig(:user, :role))
        redirect_to new_admin_user_path, alert: t("active_admin.users.role_forbidden")
        return
      end

      super
    end

    def update
      unless role_guard.allow_role_change?(record: resource, new_role: params.dig(:user, :role))
        redirect_to edit_admin_user_path(resource), alert: t("active_admin.users.role_forbidden")
        return
      end

      super
    end

    private

    def role_guard
      @role_guard ||= Admin::Users::RoleGuard.new(actor: current_user)
    end

    def restrict_master_admin_access
      return if role_guard.can_access_record?(resource)

      redirect_to admin_users_path, alert: t("active_admin.users.master_admin_hidden")
    end

    def clear_blank_passwords
      return unless params[:user].is_a?(ActionController::Parameters)

      if params[:user][:password].blank? && params[:user][:password_confirmation].blank?
        params[:user].delete(:password)
        params[:user].delete(:password_confirmation)
      end
    end
  end

  index do
    selectable_column
    id_column
    column :email
    column :name
    column :role
    column :preferred_locale
    column :created_at
    actions
  end

  filter :email
  filter :name
  filter :role, as: :select, collection: -> { Admin::Users::RoleGuard.new(actor: current_user).visible_roles }
  filter :preferred_locale
  filter :created_at

  form do |f|
    role_guard = Admin::Users::RoleGuard.new(actor: current_user)
    assignable_roles = role_guard.assignable_roles_for(record: f.object)

    f.inputs do
      f.input :email
      f.input :name
      if assignable_roles.any?
        f.input :role, as: :select, collection: assignable_roles
      end
      f.input :preferred_locale, as: :select, collection: I18n.available_locales.map(&:to_s)
      f.input :time_zone
      if f.object.new_record?
        f.input :password
        f.input :password_confirmation
      end
    end
    f.actions
  end
end
