require "rails_helper"

RSpec.describe "Admin clean environment flow", type: :request do
  let(:master_admin) { create(:user, :master_admin) }

  before do
    sign_in master_admin, scope: :user
  end

  def base_product_params(overrides = {})
    {
      slug: "starter_bundle",
      status: "active",
      sort_order: 1,
      title_en: "Starter Bundle",
      title_es: "Bundle Inicial",
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

  it "creates base content and a marketplace product with entitlements and add-on" do
    expect {
      post admin_expert_advisors_path, params: {
        expert_advisor: {
          name: "EA Alpha",
          description: "Sample EA",
          ea_type: "ea_robot",
          trial_enabled: "1",
          tier_rank: "0",
          doc_guide_en: "Guide EN",
          doc_guide_es: "Guia ES",
          tag_list: "automation"
        }
      }
    }.to change(ExpertAdvisor, :count).by(1)

    expert_advisor = ExpertAdvisor.last

    expect {
      post admin_courses_path, params: {
        course: {
          slug: "course-alpha",
          status: "draft",
          category: "intro",
          position: "0",
          title_en: "Course Alpha",
          title_es: "Curso Alpha",
          summary_en: "Summary",
          summary_es: "Resumen",
          description_en: "Description",
          description_es: "Descripcion",
          tag_list: "strategy"
        }
      }
    }.to change(Course, :count).by(1)

    course = Course.last

    expect {
      post admin_marketplace_assets_path, params: {
        marketplace_asset: {
          slug: "asset-alpha",
          status: "draft",
          sort_order: "0",
          title_en: "Asset Alpha",
          title_es: "Asset Alpha ES",
          summary_en: "Summary",
          summary_es: "Resumen",
          description_markdown_en: "Description",
          description_markdown_es: "Descripcion",
          tag_list: "risk"
        }
      }
    }.to change(MarketplaceAsset, :count).by(1)

    asset = MarketplaceAsset.last

    with_stripe_key do
      stub_stripe_product_and_price(amount_cents: 4900)

      expect {
        post admin_marketplace_products_path, params: {
          marketplace_product: base_product_params(
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

    expect(plan).to be_present
    expect(plan.addon).to be_present
    expect(plan.addon.addonable).to eq(course)
    expect(BillingPlanEntitlement.where(billing_plan: plan, expert_advisor: expert_advisor)).to exist
    expect(CoursePlanEntitlement.where(billing_plan: plan, course: course)).to exist
    expect(AssetPlanEntitlement.where(billing_plan: plan, marketplace_asset: asset)).to exist
  end
end
