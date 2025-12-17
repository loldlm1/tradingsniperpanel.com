class PagesController < ApplicationController
  before_action :redirect_signed_in_users

  def home; end

  def pricing; end

  def docs; end
end
