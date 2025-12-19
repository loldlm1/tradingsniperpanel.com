class TermsAcceptancesController < ApplicationController
  before_action :authenticate_user!
  skip_before_action :set_accessible_expert_advisors
  before_action :redirect_if_accepted

  def new
  end

  def create
    unless current_user.respond_to?(:terms_accepted_at)
      redirect_to new_user_session_path, alert: t("terms_acceptance.failure") and return
    end

    unless terms_accepted_param?
      flash.now[:alert] = t("terms_acceptance.checkbox_error")
      return render :new, status: :unprocessable_content
    end

    if current_user.update_column(:terms_accepted_at, Time.current)
      redirect_to after_sign_in_path_for(current_user), notice: t("terms_acceptance.success")
    else
      flash.now[:alert] = t("terms_acceptance.failure")
      render :new, status: :unprocessable_content
    end
  end

  private

  def terms_accepted_param?
    ActiveModel::Type::Boolean.new.cast(params[:accept_terms])
  end

  def redirect_if_accepted
    return unless current_user.respond_to?(:terms_accepted_at)
    return unless current_user.terms_accepted_at.present?

    redirect_to after_sign_in_path_for(current_user)
  end
end
