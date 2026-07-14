class PandoraJoinsController < ApplicationController
  def show
    price_key = Billing::PandoraPricing::MONTHLY_KEY
    clear_desired_plan
    store_desired_plan(price_key) if BillingPlan.purchasable.exists?(key: price_key)

    if user_signed_in?
      redirect_to signed_in_destination(price_key)
    else
      redirect_to new_user_registration_path(locale: I18n.locale, price_key: price_key)
    end
  end

  private

  def signed_in_destination(price_key)
    eligible = Discord::VipEligibility.new(user: current_user).call.eligible?
    if eligible && Discord.enabled?
      dashboard_discord_connection_path(locale: I18n.locale)
    elsif eligible
      dashboard_path(locale: I18n.locale)
    else
      dashboard_plans_path(locale: I18n.locale, price_key: price_key)
    end
  end
end
