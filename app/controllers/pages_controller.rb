class PagesController < ApplicationController
  before_action :redirect_signed_in_users

  def home
    @landing_pricing = Marketing::LandingPricing.new.call
    unless request.format.html?
      view_path = Marketing::LandingTemplate.view_path
      prepend_view_path(view_path) if view_path.exist?
    end

    # Bots and curl often send `Accept: */*`; force the marketing root to resolve
    # the HTML template instead of falling through implicit rendering heuristics.
    render template: "pages/home", formats: [ :html ]
  end
end
