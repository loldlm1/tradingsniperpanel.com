ActiveAdmin.register MarketplaceProduct do
  permit_params :slug, :status, :sort_order, :title_en, :title_es, :summary_en, :summary_es,
                :description_en, :description_es, :image

  controller do
    before_action :require_master_admin!, only: %i[new create edit update destroy]

    def create
      result = Admin::MarketplaceProductUpsert.new(
        product_attributes: product_params,
        plan_attributes: plan_params,
        entitlement_attributes: entitlement_params,
        addon_attributes: addon_params
      ).call

      if result.ok?
        redirect_to admin_marketplace_product_path(result.product),
                    notice: t("active_admin.marketplace_products.created")
      else
        @marketplace_product = result.product
        flash.now[:alert] = result.errors.to_sentence
        render :new
      end
    end

    def update
      result = Admin::MarketplaceProductUpsert.new(
        product: resource,
        product_attributes: product_params,
        plan_attributes: plan_params,
        entitlement_attributes: entitlement_params,
        addon_attributes: addon_params
      ).call

      if result.ok?
        redirect_to admin_marketplace_product_path(result.product),
                    notice: t("active_admin.marketplace_products.updated")
      else
        @marketplace_product = result.product
        flash.now[:alert] = result.errors.to_sentence
        render :edit
      end
    end

    private

    def require_master_admin!
      return if master_admin?

      redirect_to admin_marketplace_products_path, alert: t("active_admin.users.role_forbidden")
    end

    def find_resource
      scoped_collection.find_by!(slug: params[:id])
    end

    def product_params
      params.require(:marketplace_product).permit(
        :slug,
        :status,
        :sort_order,
        :title_en,
        :title_es,
        :summary_en,
        :summary_es,
        :description_en,
        :description_es,
        :image
      )
    end

    def plan_params
      attrs = params.require(:marketplace_product).permit(
        :plan_amount_cents,
        :plan_currency,
        :stripe_product_id,
        :stripe_price_id
      )
      amount_cents = attrs[:plan_amount_cents].to_s.strip
      {
        amount_cents: amount_cents.presence&.to_i,
        currency: attrs[:plan_currency].to_s.strip.presence,
        stripe_product_id: attrs[:stripe_product_id].to_s.strip.presence,
        stripe_price_id: attrs[:stripe_price_id].to_s.strip.presence
      }.compact
    end

    def entitlement_params
      params.require(:marketplace_product).permit(
        expert_advisor_ids: [],
        course_ids: [],
        marketplace_asset_ids: []
      )
    end

    def addon_params
      attrs = params.require(:marketplace_product).permit(:addonable_ref, :addon_key)
      addonable_type, addonable_id = attrs[:addonable_ref].to_s.split(":", 2)
      {
        addonable_type: addonable_type.presence,
        addonable_id: addonable_id.presence,
        addon_key: attrs[:addon_key].to_s.strip.presence
      }
    end
  end

  index do
    selectable_column
    id_column
    column :slug
    column :title_en
    column :status
    column :sort_order
    column :billing_plan do |product|
      plan = product.billing_plan
      next if plan.blank?

      admin_currency_from_cents(plan.amount_cents)
    end
    column :addon do |product|
      addonable = product.addon&.addonable
      addonable&.respond_to?(:name) ? addonable.name : addonable&.title_for(:en)
    end
    actions
  end

  filter :slug
  filter :status
  filter :title_en
  filter :title_es

  form do |f|
    f.inputs t("active_admin.marketplace_products.sections.product") do
      if f.object.persisted?
        f.input :slug, input_html: { disabled: true }
      else
        f.input :slug
      end
      f.input :status, as: :select, collection: MarketplaceProduct.statuses.keys
      f.input :sort_order
      f.input :title_en
      f.input :title_es
      f.input :summary_en
      f.input :summary_es
      f.input :description_en
      f.input :description_es
      f.input :image, as: :file
    end

    f.inputs t("active_admin.marketplace_products.sections.pricing") do
      f.input :plan_amount_cents,
              as: :number,
              input_html: { min: 0 },
              label: t("active_admin.marketplace_products.labels.plan_amount_cents")
      f.input :plan_currency,
              as: :select,
              collection: [["USD", "usd"]],
              label: t("active_admin.marketplace_products.labels.plan_currency")
      f.input :stripe_product_id, label: t("active_admin.marketplace_products.labels.stripe_product_id")
      f.input :stripe_price_id, label: t("active_admin.marketplace_products.labels.stripe_price_id")
    end

    f.inputs t("active_admin.marketplace_products.sections.entitlements") do
      f.input :expert_advisor_ids,
              as: :select,
              collection: ExpertAdvisor.ordered_by_rank.map { |ea| [ea.name, ea.id] },
              input_html: { multiple: true },
              label: t("active_admin.marketplace_products.labels.expert_advisors")
      f.input :course_ids,
              as: :select,
              collection: Course.ordered.map { |course| [course.title_en, course.id] },
              input_html: { multiple: true },
              label: t("active_admin.marketplace_products.labels.courses")
      f.input :marketplace_asset_ids,
              as: :select,
              collection: MarketplaceAsset.ordered.map { |asset| [asset.title_en, asset.id] },
              input_html: { multiple: true },
              label: t("active_admin.marketplace_products.labels.marketplace_assets")
    end

    f.inputs t("active_admin.marketplace_products.sections.addon") do
      addonable_options = {
        t("active_admin.marketplace_products.labels.addonable_expert_advisors") =>
          ExpertAdvisor.ordered_by_rank.map { |ea| ["#{ea.name} (#{ea.ea_id})", "ExpertAdvisor:#{ea.id}"] },
        t("active_admin.marketplace_products.labels.addonable_courses") =>
          Course.ordered.map { |course| ["#{course.title_en} (#{course.slug})", "Course:#{course.id}"] },
        t("active_admin.marketplace_products.labels.addonable_assets") =>
          MarketplaceAsset.ordered.map { |asset| ["#{asset.title_en} (#{asset.slug})", "MarketplaceAsset:#{asset.id}"] }
      }

      f.input :addonable_ref,
              as: :select,
              collection: addonable_options,
              include_blank: true,
              label: t("active_admin.marketplace_products.labels.addonable_ref")
      f.input :addon_key, label: t("active_admin.marketplace_products.labels.addon_key")
    end

    f.actions
  end
end
