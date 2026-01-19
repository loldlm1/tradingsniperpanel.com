require "rails_helper"

RSpec.describe "Marketplace filters", type: :request do
  let(:user) { create(:user) }

  def seed_tagged_products
    plan_one = create(:billing_plan, :one_time)
    plan_two = create(:billing_plan, :one_time)

    product_one = create(:marketplace_product, billing_plan: plan_one, title_en: "Automation Pack", title_es: "Pack Automatizacion")
    product_two = create(:marketplace_product, billing_plan: plan_two, title_en: "Manual Pack", title_es: "Pack Manual")

    expert_advisor = create(:expert_advisor, name: "Auto EA")
    expert_advisor.tag_list = "automation"
    expert_advisor.save!

    course = create(:course, slug: "manual-course", title_en: "Manual Course", title_es: "Curso Manual")
    course.tag_list = "manual"
    course.save!

    create(:billing_plan_entitlement, billing_plan: plan_one, expert_advisor: expert_advisor)
    create(:course_plan_entitlement, billing_plan: plan_two, course: course)

    [product_one, product_two]
  end

  it "filters by a single tag (EN)" do
    product_one, product_two = seed_tagged_products
    sign_in user, scope: :user
    entries = Marketplace::Catalog.new(user: user).call
    entry_map = entries.index_by { |entry| entry.product.id }

    expect(entry_map[product_one.id].tags).to eq(["automation"])
    expect(entry_map[product_two.id].tags).to eq(["manual"])

    get dashboard_marketplace_path(locale: :en, tags: ["automation"])

    expect(response).to be_successful
    expect(request.query_parameters["tags"]).to eq(["automation"])
    controller_instance = response.request.env["action_controller.instance"]
    entries = controller_instance.instance_variable_get(:@entries)
    expect(entries.map { |entry| entry.product.id }).to eq([product_one.id])
    expect(response.body).to include(product_one.title_en)
    expect(response.body).to include("automation")
  end

  it "filters by multiple tags using OR (ES)" do
    product_one, product_two = seed_tagged_products
    sign_in user, scope: :user

    get dashboard_marketplace_path(locale: :es, tags: ["automation", "manual"])

    expect(response).to be_successful
    expect(response.body).to include(product_one.title_es)
    expect(response.body).to include(product_two.title_es)
    expect(response.body).to include(I18n.t("dashboard.marketplace.filters.title", locale: :es))
  end
end
