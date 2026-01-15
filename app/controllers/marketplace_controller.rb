class MarketplaceController < ApplicationController
  layout "dashboard"
  before_action :authenticate_user!
  before_action :set_marketplace_entry, only: [:show]

  def index
    @entries = Marketplace::Catalog.new(user: current_user).call
  end

  def show; end

  private

  def set_marketplace_entry
    @entry = Marketplace::Catalog.new(user: current_user, include_eligibility: true).entry_for!(slug: params[:id])
  end
end
