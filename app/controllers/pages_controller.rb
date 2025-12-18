class PagesController < ApplicationController
  before_action :redirect_signed_in_users

  def home
    @landing_pricing = Marketing::NeonLandingPricing.new.call
  end

  def pricing
    @pricing_catalog = Billing::PricingCatalog.new.call
    @requested_price_key = params[:price_key].presence || params[:plan]
  end

  def docs; end
end
