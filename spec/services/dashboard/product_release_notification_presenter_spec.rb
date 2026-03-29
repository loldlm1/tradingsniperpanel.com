require "rails_helper"

RSpec.describe Dashboard::ProductReleaseNotificationPresenter do
  def ea_entry(expert_advisor, accessible:)
    Licenses::AccessibleExpertAdvisors::Entry.new(
      expert_advisor: expert_advisor,
      license: nil,
      status: accessible ? :active : :locked,
      accessible: accessible,
      expires_at: nil,
      license_key: nil,
      allowed_tiers: []
    )
  end

  def course_entry(course, accessible:)
    Courses::AccessibleCourses::Entry.new(
      course: course,
      accessible: accessible,
      allowed_tiers: [],
      cta_plan: nil,
      progress_percent: nil
    )
  end

  it "shows add-ons to every signed-in user while filtering EAs and courses by access" do
    user = create(:user)
    expert_advisor = create(:expert_advisor, name: "Visible EA")
    hidden_course = create(:course, title_en: "Hidden Course")
    addon_product = create(:marketplace_product, title_en: "Universal Add-on")

    release = create(:product_release)
    create(:product_release_item, product_release: release, subject: expert_advisor, product_kind: :expert_advisor, action_type: :updated, title_en: expert_advisor.name, title_es: expert_advisor.name)
    create(:product_release_item, product_release: release, subject: hidden_course, product_kind: :course, action_type: :added, title_en: hidden_course.title_en, title_es: hidden_course.title_es, position: 1)
    create(:product_release_item, product_release: release, subject: addon_product, product_kind: :addon, action_type: :added, title_en: addon_product.title_en, title_es: addon_product.title_es, position: 2)

    presenter = described_class.new(
      user: user,
      accessible_eas: [ea_entry(expert_advisor, accessible: true)],
      accessible_courses: [course_entry(hidden_course, accessible: false)],
      marketplace_available: true,
      locale: :en
    ).call

    expect(presenter).to be_present
    expect(presenter.items.map(&:title)).to eq(["Visible EA", "Universal Add-on"])
    expect(presenter.items.map(&:badge_label)).to include("EA Updated", "New Add-on")
  end

  it "falls back to the latest unread visible release when a newer one is dismissed" do
    user = create(:user)
    older_product = create(:marketplace_product, title_en: "Older Add-on")
    newer_product = create(:marketplace_product, title_en: "Newer Add-on")

    older_release = create(:product_release, published_at: 2.days.ago)
    newer_release = create(:product_release, published_at: 1.day.ago)
    create(:product_release_item, product_release: older_release, subject: older_product, title_en: older_product.title_en, title_es: older_product.title_es)
    create(:product_release_item, product_release: newer_release, subject: newer_product, title_en: newer_product.title_en, title_es: newer_product.title_es)
    create(:product_release_dismissal, user: user, product_release: newer_release)

    presenter = described_class.new(
      user: user,
      accessible_eas: [],
      accessible_courses: [],
      marketplace_available: true,
      locale: :en
    ).call

    expect(presenter.release).to eq(older_release)
    expect(presenter.items.map(&:title)).to eq(["Older Add-on"])
  end
end
