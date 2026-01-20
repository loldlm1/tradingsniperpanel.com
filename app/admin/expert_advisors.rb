ActiveAdmin.register ExpertAdvisor do
  permit_params :name, :description, :ea_type, :trial_enabled, :tier_rank, :doc_guide_en, :doc_guide_es,
                :ea_files, :tag_list

  controller do
    before_action :require_master_admin!, only: %i[new create edit update destroy]
    after_action :sync_marketplace_products, only: %i[create update]

    private

    def require_master_admin!
      return if master_admin?

      redirect_to admin_expert_advisors_path, alert: t("active_admin.users.role_forbidden")
    end

    def find_resource
      scoped_collection.find_by!(ea_id: params[:id])
    end

    def sync_marketplace_products
      return if resource.errors.any?

      resource_params = params[:expert_advisor]
      return unless resource_params.is_a?(ActionController::Parameters) || resource_params.is_a?(Hash)

      ids = resource_params[:marketplace_product_ids] || resource_params["marketplace_product_ids"]
      return if ids.nil?

      Admin::MarketplaceProductLinker.new(subject: resource, marketplace_product_ids: ids).call
    end
  end

  index do
    selectable_column
    id_column
    column :ea_id
    column :name
    column :ea_type
    column :tier_rank
    column :trial_enabled
    column :tag_list
    actions
  end

  filter :ea_id
  filter :name
  filter :ea_type, as: :select, collection: ExpertAdvisor.ea_types.keys
  filter :trial_enabled

  show do
    attributes_table do
      row :ea_id
      row :name
      row :ea_type
      row :tier_rank
      row :trial_enabled
      row :tag_list
      row :created_at
      row :updated_at
    end

    panel t("active_admin.expert_advisors.sections.bundle_coverage") do
      coverage = ExpertAdvisors::BundleCoverage.new(expert_advisor: resource).call
      if coverage.required_keys.empty?
        div t("active_admin.expert_advisors.bundle_coverage.no_addons")
      else
        attributes_table_for resource do
          row t("active_admin.expert_advisors.bundle_coverage.required") do
            coverage.required_keys.join(", ")
          end
          row t("active_admin.expert_advisors.bundle_coverage.missing") do
            coverage.missing_keys.any? ? coverage.missing_keys.join(", ") : t("active_admin.expert_advisors.bundle_coverage.complete")
          end
        end
      end
    end
  end

  form do |f|
    selected_product_ids = MarketplaceProduct.where(
      billing_plan_id: f.object.billing_plans.select(:id)
    ).pluck(:id)

    f.inputs t("active_admin.expert_advisors.sections.details") do
      if f.object.persisted?
        f.input :ea_id, input_html: { disabled: true }
      end
      f.input :name
      f.input :description
      f.input :ea_type, as: :select, collection: ExpertAdvisor.ea_types.keys
      f.input :tier_rank
      f.input :trial_enabled
      f.input :tag_list
      f.input :ea_files, as: :file
    end

    f.inputs t("active_admin.expert_advisors.sections.docs") do
      f.input :doc_guide_en
      f.input :doc_guide_es
    end

    f.inputs t("active_admin.expert_advisors.sections.marketplace_products") do
      li class: "input" do
        text_node f.template.link_to(
          t("active_admin.expert_advisors.labels.create_marketplace_product"),
          new_admin_marketplace_product_path
        )
      end
      li class: "input" do
        text_node f.template.label_tag(
          "expert_advisor_marketplace_product_ids",
          t("active_admin.expert_advisors.labels.marketplace_products")
        )
        text_node f.template.select_tag(
          "expert_advisor[marketplace_product_ids][]",
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
