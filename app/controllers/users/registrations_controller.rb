class Users::RegistrationsController < Devise::RegistrationsController
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
    params.require(:user).permit(:email, :password, :password_confirmation, :name, :preferred_locale)
  end

  def account_update_params
    params.require(:user).permit(:email, :password, :password_confirmation, :current_password, :name, :preferred_locale)
  end
end
