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

  it "renders the course show view with progress and resume CTA" do
    course = create(:course, slug: "progress-course", title_en: "Progress Course")
    one_time_plan = create(:billing_plan, :one_time)
    create(:course_plan_entitlement, course: course, billing_plan: one_time_plan)
    module_one = create(:course_module, course: course, position: 0, title_en: "Module One")
    module_two = create(:course_module, course: course, position: 1, title_en: "Module Two")
    lesson_one = create(:course_lesson, course_module: module_one, position: 0, title_en: "Lesson One")
    lesson_two = create(:course_lesson, course_module: module_one, position: 1, title_en: "Lesson Two")
    create(:course_lesson, course_module: module_two, position: 0, title_en: "Lesson Three")
    create(:course_enrollment, :one_time, user: user, course: course, progress_percent: 50, last_lesson: lesson_two)
    create(:course_lesson_progress, user: user, course_lesson: lesson_one, status: "completed", progress_seconds: 600)
    sign_in user, scope: :user

    get dashboard_course_path(course, locale: :en)

    expect(response).to be_successful
    expect(response.body).to include("Progress Course")
    expect(response.body).to include("Continue learning")
    expect(response.body).to include(dashboard_course_lesson_path(course, lesson_two, locale: :en))
    expect(response.body).to include("One-time")
    expect(response.body).to include("Module 1 - Module One")
    expect(response.body).to include("50%")
    expect(response.body).to include("data-page-size=\"4\"")
    expect(response.body).to include("data-page-size=\"3\"")
  end

  it "shows locked access and zero module progress for locked courses" do
    course = create(:course, slug: "locked-course", title_en: "Locked Course")
    module_record = create(:course_module, course: course, title_en: "Locked Module")
    lesson = create(:course_lesson, course_module: module_record, title_en: "Locked Lesson")
    plan = create(:billing_plan, tier: "basic")
    create(:course_plan_entitlement, course: course, billing_plan: plan)
    sign_in user, scope: :user

    get dashboard_course_path(course, locale: :en)

    expect(response).to be_successful
    expect(response.body).to include("Access locked")
    expect(response.body).to include("Locked Lesson")
    expect(response.body).to include("Locked")
    expect(response.body).to include("Module 1 - Locked Module")
    expect(response.body).to include("0%")
    expect(response.body).not_to include(dashboard_course_lesson_path(course, lesson, locale: :en))
  end
end
