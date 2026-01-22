require "rails_helper"

RSpec.describe "Marketplace filters", type: :request do
  let(:user) { create(:user) }

  def seed_tagged_items
    expert_advisor = create(:expert_advisor, name: "Auto EA")
    expert_advisor.tag_list = "automation"
    expert_advisor.save!

    ea_plan = create(:billing_plan, :one_time, key: "marketplace_ea_auto")
    ea_product = create(:marketplace_product, billing_plan: ea_plan, title_en: "Auto Bundle", title_es: "Bundle Auto")
    create(:billing_plan_entitlement, expert_advisor: expert_advisor, billing_plan: ea_plan)

    course = create(:course, slug: "manual-course", title_en: "Manual Course", title_es: "Curso Manual")
    course.tag_list = "manual"
    course.save!

    course_plan = create(:billing_plan, :one_time, key: "marketplace_manual_course")
    course_product = create(:marketplace_product, billing_plan: course_plan, title_en: "Manual Bundle", title_es: "Bundle Manual")
    create(:course_plan_entitlement, course: course, billing_plan: course_plan)

    [course_product, ea_product]
  end

  it "filters by a single tag (EN)" do
    course_product, ea_product = seed_tagged_items
    sign_in user, scope: :user

    get dashboard_marketplace_path(locale: :en, tags: ["automation"])

    expect(response).to be_successful
    expect(request.query_parameters["tags"]).to eq(["automation"])
    controller_instance = response.request.env["action_controller.instance"]
    marketplace = controller_instance.instance_variable_get(:@marketplace)
    expect(marketplace.selected_tags).to eq(["automation"])
    expect(marketplace.course_cards).to be_empty
    expect(marketplace.digital_goods_cards.map(&:title)).to include(ea_product.title_en)
    expect(response.body).to include(ea_product.title_en)
    expect(response.body).not_to include(I18n.t("dashboard.marketplace.sections.courses", locale: :en))
    expect(response.body).to include("automation")
  end

  it "filters by multiple tags using OR (ES)" do
    course_product, ea_product = seed_tagged_items
    sign_in user, scope: :user

    get dashboard_marketplace_path(locale: :es, tags: ["automation", "manual"])

    expect(response).to be_successful
    expect(response.body).to include(course_product.title_es)
    expect(response.body).to include(ea_product.title_es)
    expect(response.body).to include(I18n.t("dashboard.marketplace.tabs.all", locale: :es))
  end

  it "searches by expert advisor type without SQL errors" do
    expert_advisor = create(:expert_advisor, name: "Tool EA", ea_type: :ea_tool)
    plan = create(:billing_plan, :one_time, key: "marketplace_ea_tool")
    product = create(:marketplace_product, billing_plan: plan, title_en: "EA Tool Pack")
    create(:billing_plan_entitlement, expert_advisor: expert_advisor, billing_plan: plan)
    sign_in user, scope: :user

    get dashboard_marketplace_path(locale: :en, q: "ea_tool", tab: "expert_advisors")

    expect(response).to be_successful
    expect(response.body).to include(product.title_en)
  end

  it "searches by course category without SQL errors" do
    course = create(:course, title_en: "Beginner Course", category: "beginner")
    plan = create(:billing_plan, :one_time, key: "marketplace_beginner_course")
    product = create(:marketplace_product, billing_plan: plan, title_en: "Beginner Course Pack")
    create(:course_plan_entitlement, course: course, billing_plan: plan)
    sign_in user, scope: :user

    get dashboard_marketplace_path(locale: :en, q: "beginner", tab: "courses")

    expect(response).to be_successful
    expect(response.body).to include(product.title_en)
  end
end
