ActiveAdmin.register ExpertAdvisorBundle do
  permit_params :expert_advisor_id, :required_addon_keys, :bundle_key, :active, :sort_order, :bundle_file

  controller do
    before_action :assign_bundle_key, only: %i[create update]

    private

    def assign_bundle_key
      return unless params[:expert_advisor_bundle].is_a?(ActionController::Parameters)

      required = params[:expert_advisor_bundle][:required_addon_keys]
      expected = ExpertAdvisorBundle.new(required_addon_keys: required).expected_bundle_key
      params[:expert_advisor_bundle][:bundle_key] = expected
    end
  end

  index do
    selectable_column
    id_column
    column :expert_advisor
    column :bundle_key
    column :required_addon_keys
    column :active
    column :sort_order
    column :bundle_file do |bundle|
      bundle.bundle_file.attached? ? bundle.bundle_file.filename.to_s : "-"
    end
    actions
  end

  filter :expert_advisor
  filter :bundle_key
  filter :active

  form do |f|
    f.inputs t("active_admin.expert_advisor_bundles.sections.details") do
      f.input :expert_advisor
      f.input :required_addon_keys
      f.input :bundle_key, input_html: { disabled: true, value: f.object.expected_bundle_key }
      f.input :active
      f.input :sort_order
      f.input :bundle_file, as: :file
    end
    f.actions
  end
end
