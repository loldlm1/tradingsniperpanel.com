require "rails_helper"

RSpec.describe "Marketplace products admin", type: :request do
  def base_product_params(overrides = {})
    {
      slug: "marketplace_bundle",
      status: "active",
      sort_order: 1,
      title_en: "Marketplace Bundle",
      title_es: "Bundle Marketplace",
      summary_en: "Summary",
      summary_es: "Resumen",
      description_en: "Description",
      description_es: "Descripcion",
      plan_amount_cents: "4900",
      plan_currency: "usd",
      stripe_product_id: "",
      stripe_price_id: "",
      expert_advisor_ids: [],
      course_ids: [],
      marketplace_asset_ids: [],
      addonable_ref: "",
      addon_key: ""
    }.merge(overrides)
  end

  def update_params_for(product, overrides = {})
    plan = product.billing_plan
    base_product_params(
      slug: product.slug,
      status: product.status,
      sort_order: product.sort_order,
      title_en: product.title_en,
      title_es: product.title_es,
      summary_en: product.summary_en,
      summary_es: product.summary_es,
      description_en: product.description_en,
      description_es: product.description_es,
      plan_amount_cents: plan.amount_cents.to_s,
      plan_currency: plan.currency,
      stripe_product_id: plan.stripe_product_id.to_s,
      stripe_price_id: plan.stripe_price_id.to_s
    ).merge(overrides)
  end

  describe "POST /admin/marketplace_products" do
    it "allows admins to create marketplace products" do
      admin = create(:user, :admin)
      sign_in admin, scope: :user

      with_stripe_key do
        stub_stripe_product_and_price(amount_cents: 4900)

        expect {
          post admin_marketplace_products_path, params: {
            marketplace_product: base_product_params
          }
        }.to change(MarketplaceProduct, :count).by(1)
      end

      expect(response).to redirect_to(admin_marketplace_product_path(MarketplaceProduct.last))
    end

    it "allows master admins to create marketplace products with entitlements and add-ons" do
      master_admin = create(:user, :master_admin)
      expert_advisor = create(:expert_advisor)
      course = create(:course)
      asset = create(:marketplace_asset)
      sign_in master_admin, scope: :user

      with_stripe_key do
        stub_stripe_product_and_price(amount_cents: 4900)

        expect {
          post admin_marketplace_products_path, params: {
            marketplace_product: base_product_params(
              slug: "ultimate_bundle",
              expert_advisor_ids: [expert_advisor.id],
              course_ids: [course.id],
              marketplace_asset_ids: [asset.id],
              addonable_ref: "Course:#{course.id}"
            )
          }
        }.to change(MarketplaceProduct, :count).by(1)
      end

      product = MarketplaceProduct.last
      plan = product.billing_plan
      addon = plan.addon

      expect(plan.stripe_product_id).to eq("prod_admin")
      expect(plan.stripe_price_id).to eq("price_admin")
      expect(addon).to be_present
      expect(addon.key).to eq(product.slug)
      expect(addon.addonable).to eq(course)
      expect(BillingPlanEntitlement.where(billing_plan: plan, expert_advisor: expert_advisor)).to exist
      expect(CoursePlanEntitlement.where(billing_plan: plan, course: course)).to exist
      expect(AssetPlanEntitlement.where(billing_plan: plan, marketplace_asset: asset)).to exist
    end

    it "blocks marketplace product creation when amount is missing" do
      master_admin = create(:user, :master_admin)
      sign_in master_admin, scope: :user

      expect {
        post admin_marketplace_products_path, params: {
          marketplace_product: base_product_params(plan_amount_cents: "")
        }
      }.not_to change(MarketplaceProduct, :count)

      expect(response).to have_http_status(:ok)
      expect(flash[:alert]).to include(I18n.t("active_admin.marketplace_products.errors.amount_missing"))
    end

    it "blocks asset add-ons without a base marketplace product" do
      master_admin = create(:user, :master_admin)
      asset = create(:marketplace_asset)
      sign_in master_admin, scope: :user

      with_stripe_key do
        stub_stripe_product_and_price(amount_cents: 4900)

        expect {
          post admin_marketplace_products_path, params: {
            marketplace_product: base_product_params(
              slug: "asset_addon",
              addonable_ref: "MarketplaceAsset:#{asset.id}"
            )
          }
        }.not_to change(MarketplaceProduct, :count)
      end

      expect(response).to have_http_status(:ok)
      expect(flash[:alert]).to include(I18n.t("active_admin.marketplace_products.errors.asset_base_missing"))
    end

    it "blocks EA add-ons when required bundles are missing" do
      master_admin = create(:user, :master_admin)
      expert_advisor = create(:expert_advisor)
      sign_in master_admin, scope: :user

      with_stripe_key do
        stub_stripe_product_and_price(amount_cents: 4900)

        expect {
          post admin_marketplace_products_path, params: {
            marketplace_product: base_product_params(
              slug: "ea_addon",
              addonable_ref: "ExpertAdvisor:#{expert_advisor.id}"
            )
          }
        }.not_to change(MarketplaceProduct, :count)
      end

      expect(response).to have_http_status(:ok)
      expect(flash[:alert]).to include(
        I18n.t("active_admin.marketplace_products.errors.bundle_missing", keys: "base, ea_addon")
      )
    end

    it "blocks marketplace product creation when Stripe fails" do
      master_admin = create(:user, :master_admin)
      sign_in master_admin, scope: :user

      with_stripe_key do
        stub_stripe_product_and_price(amount_cents: 4900)
        allow(Stripe::Product).to receive(:create).and_raise(Stripe::InvalidRequestError.new("boom", nil))

        expect {
          post admin_marketplace_products_path, params: {
            marketplace_product: base_product_params(slug: "stripe_fail")
          }
        }.not_to change(MarketplaceProduct, :count)
      end

      expect(response).to have_http_status(:ok)
      expect(flash[:alert]).to include("boom")
    end
  end

  describe "PATCH /admin/marketplace_products/:id" do
    it "allows admins to update marketplace products" do
      admin = create(:user, :admin)
      product = create(:marketplace_product)
      sign_in admin, scope: :user

      with_stripe_key do
        stub_stripe_product_and_price(
          amount_cents: product.billing_plan.amount_cents,
          product_id: product.billing_plan.stripe_product_id,
          price_id: product.billing_plan.stripe_price_id
        )

        patch admin_marketplace_product_path(product), params: {
          marketplace_product: update_params_for(product)
        }
      end

      expect(response).to redirect_to(admin_marketplace_product_path(product))
    end

    it "updates entitlements and removes unselected ones" do
      master_admin = create(:user, :master_admin)
      product = create(:marketplace_product)
      expert_advisor_one = create(:expert_advisor)
      expert_advisor_two = create(:expert_advisor)
      create(:billing_plan_entitlement, billing_plan: product.billing_plan, expert_advisor: expert_advisor_one)
      create(:billing_plan_entitlement, billing_plan: product.billing_plan, expert_advisor: expert_advisor_two)
      sign_in master_admin, scope: :user

      with_stripe_key do
        stub_stripe_product_and_price(
          amount_cents: product.billing_plan.amount_cents,
          product_id: product.billing_plan.stripe_product_id,
          price_id: product.billing_plan.stripe_price_id
        )

        patch admin_marketplace_product_path(product), params: {
          marketplace_product: update_params_for(
            product,
            expert_advisor_ids: [expert_advisor_one.id]
          )
        }
      end

      plan = product.billing_plan
      plan_ids = BillingPlanEntitlement.where(billing_plan: plan).pluck(:expert_advisor_id)
      expect(plan_ids).to eq([expert_advisor_one.id])
    end
  end
end
