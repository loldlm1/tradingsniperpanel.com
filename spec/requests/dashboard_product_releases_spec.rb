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

  it "shows EA update items to users who can access that EA on the real dashboard route" do
    expert_advisor = create(:expert_advisor, name: "Visible EA Update")
    create(:license, user: user, expert_advisor: expert_advisor, status: :active, trial_ends_at: nil, expires_at: 2.weeks.from_now)

    release = create(:product_release)
    create(
      :product_release_item,
      product_release: release,
      subject: expert_advisor,
      product_kind: :expert_advisor,
      action_type: :updated,
      title_en: expert_advisor.name,
      title_es: expert_advisor.name
    )

    get dashboard_path(locale: :en)

    expect(response).to have_http_status(:ok)
    expect(parsed_body.at_css("[data-product-release-bell-dot='true']")).to be_present

    dropdown_text = parsed_body.at_css("[data-product-release-dropdown='true']")&.text.to_s
    expect(dropdown_text).to include("EA Updated")
    expect(dropdown_text).to include("Visible EA Update")
  end

  it "shows unread releases from newest to oldest" do
    older_product = create(:marketplace_product, title_en: "Older Add-on")
    newer_product = create(:marketplace_product, title_en: "Newer Add-on")

    older_release = create(:product_release, published_at: 2.days.ago)
    newer_release = create(:product_release, published_at: 1.day.ago)
    create(:product_release_item, product_release: older_release, subject: older_product, product_kind: :addon, action_type: :added, title_en: older_product.title_en, title_es: older_product.title_es)
    create(:product_release_item, product_release: newer_release, subject: newer_product, product_kind: :addon, action_type: :added, title_en: newer_product.title_en, title_es: newer_product.title_es)

    get dashboard_path(locale: :en)

    expect(response).to have_http_status(:ok)

    release_groups = parsed_body.css("[data-product-release-group='true']").map { |node| node.text.squish }
    expect(release_groups.first).to include("Newer Add-on")
    expect(release_groups.last).to include("Older Add-on")
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

  it "clears all visible unread releases for the current user" do
    older_product = create(:marketplace_product, title_en: "Dismissible Older Add-on")
    newer_product = create(:marketplace_product, title_en: "Dismissible Newer Add-on")
    hidden_course = create(:course, title_en: "Hidden Dismiss Course", title_es: "Curso Dismiss Oculto")
    create(:course_plan_entitlement, course: hidden_course, billing_plan: create(:billing_plan, tier: "pro"))

    older_release = create(:product_release, published_at: 2.days.ago)
    newer_release = create(:product_release, published_at: 1.day.ago)
    hidden_release = create(:product_release, published_at: 3.days.ago)
    create(:product_release_item, product_release: older_release, subject: older_product, product_kind: :addon, action_type: :added, title_en: older_product.title_en, title_es: older_product.title_es)
    create(:product_release_item, product_release: newer_release, subject: newer_product, product_kind: :addon, action_type: :added, title_en: newer_product.title_en, title_es: newer_product.title_es)
    create(:product_release_item, product_release: hidden_release, subject: hidden_course, product_kind: :course, action_type: :added, title_en: hidden_course.title_en, title_es: hidden_course.title_es)

    expect {
      post clear_dashboard_product_releases_path(locale: :en), headers: { "HTTP_REFERER" => dashboard_path(locale: :en) }
    }.to change(ProductReleaseDismissal, :count).by(2)

    expect(response).to redirect_to(dashboard_path(locale: :en))

    get dashboard_path(locale: :en)
    expect(parsed_body.at_css("[data-product-release-bell-dot='true']")).to be_nil
    expect(user.product_release_dismissals.pluck(:product_release_id)).to contain_exactly(older_release.id, newer_release.id)
  end
end
