class PagesController < ApplicationController
  before_action :redirect_signed_in_users

  def home
    @landing_pricing = Marketing::NeonLandingPricing.new.call
  end

  def pricing; end

  def docs; end
end
