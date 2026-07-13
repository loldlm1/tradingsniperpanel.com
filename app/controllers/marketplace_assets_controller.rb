class MarketplaceAssetsController < ApplicationController
  layout "dashboard"
  before_action :authenticate_user!
  before_action :set_marketplace_asset
  before_action :ensure_access!
  before_action :set_markdown, only: [ :show ]

  def show; end

  def download
    unless @marketplace_asset.file.attached?
      redirect_back fallback_location: dashboard_path(locale: I18n.locale),
                    alert: t("dashboard.marketplace.assets.missing_file")
      return
    end

    redirect_to rails_blob_path(@marketplace_asset.file, disposition: "attachment")
  end

  private

  def set_marketplace_asset
    @marketplace_asset = MarketplaceAsset.find_by!(slug: params[:id])
  end

  def ensure_access!
    access = Marketplace::AssetAccess.new(user: current_user, asset: @marketplace_asset).call
    return if access.allowed?

    redirect_to dashboard_path(locale: I18n.locale),
                alert: t("dashboard.marketplace.assets.access_denied")
  end

  def set_markdown
    markdown = @marketplace_asset.description_markdown_for(I18n.locale)
    return if markdown.blank?

    rendered = MarkdownRenderer.render(markdown, with_toc: true)
    @markdown_html = rendered[:html]
    @doc_headings = rendered[:headings]
  end
end
