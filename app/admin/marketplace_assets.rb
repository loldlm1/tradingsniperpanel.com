ActiveAdmin.register MarketplaceAsset do
  permit_params :slug, :status, :sort_order, :title_en, :title_es, :summary_en, :summary_es,
                :description_markdown_en, :description_markdown_es, :file, :tag_list

  controller do
    before_action :require_master_admin!, only: %i[new create edit update destroy]
    after_action :sync_marketplace_products, only: %i[create update]

    private

    def require_master_admin!
      return if master_admin?

      redirect_to admin_marketplace_assets_path, alert: t("active_admin.users.role_forbidden")
    end

    def find_resource
      scoped_collection.find_by!(slug: params[:id])
    end

    def sync_marketplace_products
      return if resource.errors.any?

      resource_params = params[:marketplace_asset]
      return unless resource_params.is_a?(ActionController::Parameters) || resource_params.is_a?(Hash)

      ids = resource_params[:marketplace_product_ids] || resource_params["marketplace_product_ids"]
      return if ids.nil?

      Admin::MarketplaceProductLinker.new(subject: resource, marketplace_product_ids: ids).call
    end
  end

  index do
    selectable_column
    id_column
    column :slug
    column :title_en
    column :status
    column :sort_order
    column :tag_list
    actions
  end

  filter :slug
  filter :status
  filter :title_en
  filter :title_es

  form do |f|
    f.inputs t("active_admin.marketplace_assets.sections.details") do
      f.input :slug
      f.input :status, as: :select, collection: MarketplaceAsset.statuses.keys
      f.input :sort_order
      f.input :title_en
      f.input :title_es
      f.input :summary_en
      f.input :summary_es
      f.input :description_markdown_en
      f.input :description_markdown_es
      f.input :tag_list
      f.input :file, as: :file
    end

    f.inputs t("active_admin.marketplace_assets.sections.marketplace_products") do
      f.input :marketplace_product_ids,
              as: :select,
              collection: MarketplaceProduct.ordered.map { |product| [product.title_en, product.id] },
              input_html: { multiple: true },
              label: t("active_admin.marketplace_assets.labels.marketplace_products"),
              hint: f.template.link_to(
                t("active_admin.marketplace_assets.labels.create_marketplace_product"),
                new_admin_marketplace_product_path
              )
    end

    f.actions
  end
end
