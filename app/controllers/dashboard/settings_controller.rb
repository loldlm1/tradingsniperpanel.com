module Dashboard
  class SettingsController < ApplicationController
    layout "dashboard"

    before_action :authenticate_user!

    def show
      @user = current_user
    end

    def update
      @user = current_user
      result = Users::AccountSettingsUpdater.new(user: @user, params: account_params).call

      if result.success?
        bypass_sign_in(@user) if result.password_changed?
        redirect_to dashboard_settings_path, notice: t("dashboard.settings.updated")
      else
        render :show, status: :unprocessable_content
      end
    end

    private

    def account_params
      params.require(:user).permit(:name, :current_password, :password, :password_confirmation)
    end
  end
end
