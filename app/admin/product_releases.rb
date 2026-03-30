ActiveAdmin.register ProductRelease do
  actions :index, :show

  config.sort_order = "published_at_desc"

  controller do
    def scoped_collection
      super.includes(:published_by, :product_release_items)
    end
  end

  collection_action :publish, method: :post do
    result = ProductReleases::Publish.new(published_by: current_user).call

    if result.published?
      redirect_to admin_product_release_path(result.release),
                  notice: t("active_admin.product_releases.publish.success", count: result.item_count)
    else
      redirect_to admin_product_releases_path,
                  notice: t("active_admin.product_releases.publish.no_changes")
    end
  rescue StandardError => e
    redirect_to admin_product_releases_path, alert: e.message
  end

  action_item :publish, only: :index do
    link_to t("active_admin.product_releases.actions.publish"), publish_admin_product_releases_path, method: :post
  end

  index do
    selectable_column
    id_column
    column :published_at
    column :published_by
    column :created_at
    column t("active_admin.product_releases.labels.items") do |release|
      release.product_release_items.size
    end
    actions
  end

  filter :published_at
  filter :published_by
  filter :created_at

  show do
    attributes_table do
      row :id
      row :published_at
      row :published_by
      row :created_at
      row :updated_at
    end

    panel t("active_admin.product_releases.sections.items") do
      table_for resource.product_release_items do
        column :position
        column :product_kind do |item|
          item.product_kind.humanize
        end
        column :action_type do |item|
          item.action_type.humanize
        end
        column :title_en
        column :title_es
        column :subject do |item|
          next "#{item.subject_type}##{item.subject_id}" unless item.subject.present?

          auto_link(item.subject)
        end
      end
    end
  end
end
