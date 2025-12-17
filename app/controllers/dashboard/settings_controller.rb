module Dashboard
  class SettingsController < ApplicationController
    layout "dashboard"

    before_action :authenticate_user!
    before_action :set_user_expert_advisors

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

    def set_user_expert_advisors
      @user_expert_advisors = current_user.user_expert_advisors.active.includes(:expert_advisor)
    end

    def account_params
      params.require(:user).permit(:name, :current_password, :password, :password_confirmation)
    end
  end
end

