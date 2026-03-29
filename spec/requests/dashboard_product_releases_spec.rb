require "rails_helper"

RSpec.describe "Dashboard product releases", type: :request do
  let(:user) { create(:user) }

  before do
    sign_in user, scope: :user
  end

  def parsed_body
    Nokogiri::HTML(response.body)
  end

  it "shows the unread notification dot and release items for visible add-ons" do
    addon_product = create(:marketplace_product, title_en: "Session Filter", title_es: "Filtro de Sesion")
    release = create(:product_release)
    create(:product_release_item, product_release: release, subject: addon_product, product_kind: :addon, action_type: :added, title_en: addon_product.title_en, title_es: addon_product.title_es)

    get dashboard_path(locale: :en)

    expect(response).to have_http_status(:ok)
    expect(parsed_body.at_css("[data-product-release-bell-dot='true']")).to be_present
    expect(response.body).to include("Session Filter")
  end

  it "does not show course releases when the signed-in user cannot access the course" do
    course = create(:course, title_en: "Locked Course", title_es: "Curso Bloqueado")
    create(:course_plan_entitlement, course: course, billing_plan: create(:billing_plan, tier: "pro"))
    release = create(:product_release)
    create(:product_release_item, product_release: release, subject: course, product_kind: :course, action_type: :added, title_en: course.title_en, title_es: course.title_es)

    get dashboard_path(locale: :en)

    expect(response).to have_http_status(:ok)
    expect(parsed_body.at_css("[data-product-release-bell-dot='true']")).to be_nil
    expect(response.body).to include(I18n.t("dashboard.product_releases.empty", locale: :en))
  end

  it "persists release dismissal for the current user" do
    addon_product = create(:marketplace_product, title_en: "Dismissible Add-on")
    release = create(:product_release)
    create(:product_release_item, product_release: release, subject: addon_product, product_kind: :addon, action_type: :added, title_en: addon_product.title_en, title_es: addon_product.title_es)

    expect {
      post dismiss_dashboard_product_release_path(release, locale: :en), headers: { "HTTP_REFERER" => dashboard_path(locale: :en) }
    }.to change(ProductReleaseDismissal, :count).by(1)

    expect(response).to redirect_to(dashboard_path(locale: :en))

    get dashboard_path(locale: :en)
    expect(parsed_body.at_css("[data-product-release-bell-dot='true']")).to be_nil
  end
end
