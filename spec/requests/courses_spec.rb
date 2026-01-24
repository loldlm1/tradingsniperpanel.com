require "rails_helper"

RSpec.describe "Courses", type: :request do
  let(:user) { create(:user) }

  it "renders the courses index" do
    course = create(:course, title_en: "Trading Foundations")
    sign_in user, scope: :user

    get dashboard_courses_path(locale: :en)

    expect(response).to be_successful
    expect(response.body).to include("Trading Foundations")
  end

  it "prefers marketplace unlock links when available" do
    course = create(:course, slug: "marketplace-course", title_en: "Marketplace Course")
    subscription_plan = create(:billing_plan, tier: "pro")
    create(:course_plan_entitlement, course: course, billing_plan: subscription_plan)
    product = create(:marketplace_product, title_en: "Marketplace Course Product")
    create(:course_plan_entitlement, course: course, billing_plan: product.billing_plan)
    sign_in user, scope: :user

    get dashboard_courses_path(locale: :en)

    expect(response).to be_successful
    expect(response.body).to include(dashboard_marketplace_product_path(product, locale: :en))
  end

  it "allows access to a free course but blocks locked lessons" do
    paid_course = create(:course, slug: "paid-course")
    module_record = create(:course_module, course: paid_course)
    lesson = create(:course_lesson, course_module: module_record, title_en: "Locked Lesson")
    plan = create(:billing_plan, tier: "basic")
    create(:course_plan_entitlement, course: paid_course, billing_plan: plan)
    sign_in user, scope: :user

    get dashboard_course_path(paid_course, locale: :en)

    expect(response).to be_successful
    expect(response.body).to include("Locked Lesson")

    get dashboard_course_lesson_path(paid_course, lesson, locale: :en)

    expect(response).to have_http_status(:found)
    expect(response.headers["Location"]).to include("/dashboard/courses/paid-course")
  end

  it "redirects when the lesson does not belong to the course" do
    course = create(:course, slug: "course-a")
    other_course = create(:course, slug: "course-b")
    module_record = create(:course_module, course: other_course)
    lesson = create(:course_lesson, course_module: module_record)
    sign_in user, scope: :user

    get dashboard_course_lesson_path(course, lesson, locale: :en)

    expect(response).to have_http_status(:found)
    expect(response.headers["Location"]).to include("/dashboard/courses/course-a")
  end

  it "redirects when the course is missing" do
    sign_in user, scope: :user

    get dashboard_course_lesson_path("missing-course", 123, locale: :en)

    expect(response).to have_http_status(:found)
    expect(response.headers["Location"]).to include("/dashboard/courses")
  end

  it "allows lesson access for free courses" do
    free_course = create(:course, slug: "free-course")
    module_record = create(:course_module, course: free_course)
    lesson = create(:course_lesson, course_module: module_record, title_en: "Free Lesson")
    sign_in user, scope: :user

    get dashboard_course_lesson_path(free_course, lesson, locale: :en)

    expect(response).to be_successful
    expect(response.body).to include("Free Lesson")
  end
end
