class PagesController < ApplicationController
  before_action :redirect_signed_in_users

  def home
    @landing_pricing = Marketing::LandingPricing.new.call
  end
end
