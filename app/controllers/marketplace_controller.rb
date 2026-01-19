class MarketplaceController < ApplicationController
  layout "dashboard"
  before_action :authenticate_user!
  before_action :set_marketplace_entry, only: [:show]

  def index
    catalog_entries = Marketplace::Catalog.new(user: current_user).call
    @available_tags = available_tags_for(catalog_entries)
    @selected_tags = normalized_tags(params[:tags])
    @entries = filter_entries(catalog_entries, @selected_tags)
  end

  def show; end

  private

  def set_marketplace_entry
    @entry = Marketplace::Catalog.new(user: current_user, include_eligibility: true).entry_for!(slug: params[:id])
  end

  def available_tags_for(entries)
    entries.flat_map(&:tags).uniq.sort_by { |tag| tag.downcase }
  end

  def normalized_tags(value)
    Array(value).map(&:to_s).map(&:strip).reject(&:blank?).uniq
  end

  def filter_entries(entries, selected_tags)
    return entries if selected_tags.blank?

    entries.select { |entry| (entry.tags & selected_tags).any? }
  end
end
