ActiveAdmin.register Course do
  permit_params :slug, :status, :category, :position, :published_at, :title_en, :title_es, :summary_en, :summary_es,
                :description_en, :description_es, :tag_list

  controller do
    before_action :require_master_admin!, only: %i[new create edit update destroy]
    after_action :sync_marketplace_products, only: %i[create update]

    private

    def require_master_admin!
      return if master_admin?

      redirect_to admin_courses_path, alert: t("active_admin.users.role_forbidden")
    end

    def find_resource
      scoped_collection.find_by!(slug: params[:id])
    end

    def sync_marketplace_products
      return if resource.errors.any?

      resource_params = params[:course]
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
    column :category
    column :position
    column :tag_list
    actions
  end

  filter :slug
  filter :status
  filter :category
  filter :title_en
  filter :title_es

  form do |f|
    selected_product_ids = MarketplaceProduct.where(
      billing_plan_id: f.object.billing_plans.select(:id)
    ).pluck(:id)

    f.inputs t("active_admin.courses.sections.details") do
      f.input :slug
      f.input :status, as: :select, collection: %w[draft published]
      f.input :category
      f.input :position
      f.input :published_at, as: :date_picker
      f.input :title_en
      f.input :title_es
      f.input :summary_en
      f.input :summary_es
      f.input :description_en
      f.input :description_es
      f.input :tag_list
    end

    f.inputs t("active_admin.courses.sections.marketplace_products") do
      li class: "input" do
        text_node f.template.link_to(
          t("active_admin.courses.labels.create_marketplace_product"),
          new_admin_marketplace_product_path
        )
      end
      li class: "input" do
        text_node f.template.label_tag(
          "course_marketplace_product_ids",
          t("active_admin.courses.labels.marketplace_products")
        )
        text_node f.template.select_tag(
          "course[marketplace_product_ids][]",
          f.template.options_from_collection_for_select(
            MarketplaceProduct.ordered,
            :id,
            :title_en,
            selected_product_ids
          ),
          multiple: true
        )
      end
    end

    f.actions
  end
end
