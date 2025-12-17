class Users::SessionsController < Devise::SessionsController
  before_action :redirect_if_authenticated, only: [:new]

  def create
    super
  end
end
