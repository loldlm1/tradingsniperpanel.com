class PagesController < ApplicationController
  before_action :redirect_signed_in_users

  def home
    @landing_pricing = Marketing::LandingPricing.new.call
    @discount_banner = Marketing::DiscountBanner.new.call
  end
end
