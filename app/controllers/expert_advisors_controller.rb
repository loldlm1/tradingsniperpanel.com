class ExpertAdvisorsController < ApplicationController
  layout "dashboard"
  before_action :authenticate_user!
  before_action :set_user_expert_advisors
  before_action :set_expert_advisor

  def docs; end

  private

  def set_user_expert_advisors
    @user_expert_advisors = current_user.user_expert_advisors.active.includes(:expert_advisor)
  end

  def set_expert_advisor
    @expert_advisor = @user_expert_advisors.find_by!(expert_advisor_id: params[:id]).expert_advisor
  end
end
