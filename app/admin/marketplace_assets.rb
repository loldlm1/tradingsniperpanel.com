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

    def sync_marketplace_products
      return if resource.errors.any?
      return unless params[:marketplace_asset].is_a?(ActionController::Parameters)

      ids = params[:marketplace_asset][:marketplace_product_ids]
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
    selected_product_ids = MarketplaceProduct.where(
      billing_plan_id: f.object.billing_plans.select(:id)
    ).pluck(:id)

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
      f.template.concat f.template.content_tag(:li, class: "input") {
        f.template.link_to(
          t("active_admin.marketplace_assets.labels.create_marketplace_product"),
          new_admin_marketplace_product_path
        )
      }
      f.template.concat f.template.content_tag(:li, class: "input") {
        f.template.label_tag(
          "marketplace_asset_marketplace_product_ids",
          t("active_admin.marketplace_assets.labels.marketplace_products")
        ) +
          f.template.select_tag(
            "marketplace_asset[marketplace_product_ids][]",
            f.template.options_from_collection_for_select(
              MarketplaceProduct.ordered,
              :id,
              :title_en,
              selected_product_ids
            ),
            multiple: true
          )
      }
    end

    f.actions
  end
end
