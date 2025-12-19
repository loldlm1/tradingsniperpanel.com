class Users::RegistrationsController < Devise::RegistrationsController
  before_action :redirect_if_authenticated, only: [:new]
  before_action :set_locale_on_params, only: [:create]

  def edit
    redirect_to dashboard_settings_path
  end

  def update
    redirect_to dashboard_settings_path
  end

  def create
    super do |resource|
      if resource.persisted?
        refer(resource)
        resource.update(preferred_locale: I18n.locale.to_s) if resource.preferred_locale != I18n.locale.to_s
      end
    end
  end

  private

  def sign_up_params
    params.require(:user).permit(:email, :password, :password_confirmation, :name, :preferred_locale, :terms_of_service)
  end

  def account_update_params
    params.require(:user).permit(:email, :password, :password_confirmation, :current_password, :name, :preferred_locale)
  end

  def set_locale_on_params
    params[:user][:preferred_locale] = I18n.locale.to_s if params[:user]
  end
end
