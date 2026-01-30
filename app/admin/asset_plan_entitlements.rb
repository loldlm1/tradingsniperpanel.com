ActiveAdmin.register AssetPlanEntitlement do
  permit_params :billing_plan_id, :marketplace_asset_id

  controller do
    def scoped_collection
      super.includes(:billing_plan, :marketplace_asset)
    end
  end

  index do
    selectable_column
    id_column
    column :billing_plan
    column :marketplace_asset
    column :created_at
    actions
  end

  filter :billing_plan, as: :select, collection: -> { BillingPlan.ordered }
  filter :marketplace_asset
  filter :created_at

  form do |f|
    f.inputs t("active_admin.plan_entitlements.sections.details") do
      f.input :billing_plan, collection: BillingPlan.ordered.map { |plan| ["#{plan.name} (#{plan.key})", plan.id] }
      f.input :marketplace_asset, collection: MarketplaceAsset.ordered.map { |asset| [asset.title_en, asset.id] }
    end
    f.actions
  end
end
