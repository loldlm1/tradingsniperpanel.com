# Dashboard Marketplace Index - content proposal (trader)

## Objective
Propose content for each card in `dashboard_marketplace_index.html` using `database_model_reference.md`, focused on sales, retention, and acquisition for the trader.

## Data sources
- `expert_advisors`, `licenses`, `broker_account_daily_results`, `expert_advisor_bundles`
- `courses`, `course_modules`, `course_lessons`, `course_enrollments`, `course_lesson_progresses`, `course_plan_entitlements`
- `billing_plans`, `billing_plan_entitlements`, `addons`
- `pay_charges`, `pay_subscriptions`
- `refer_visits`, `refer_referrals` (acquisition)

## Index
- Global elements
  - Page header
  - Search form
  - Filters
- Cards 1 (Video Courses)
  - Card 1: Best selling course
  - Card 2: Highest completion course
  - Card 3: Most recent course
  - Card 4: Recommended for you
- Cards 2 (Digital Goods)
  - Card 1: Most used Expert Advisor
  - Card 2: Expert Advisor with best 30-day Profit & Loss
  - Card 3: New tool/Expert Advisor
  - Card 4: Expert Advisor with best retention
- Cards 3 (Online Events)
  - Card 1: Best selling premium session
  - Card 2: Nearest upcoming session
  - Card 3: Featured premium course
  - Card 4: Promotional add-on
- Cards 5 (Popular Categories)
  - Card 1: Expert Advisors (robots)
  - Card 2: Tools (EA tools)
  - Card 3: Top course category
  - Card 4: Add-ons and bundles
- Cards 6 (Trending Now)
  - Card 1: Expert Advisor with most recent sales
  - Card 2: Course with most new enrollments
  - Card 3: Add-on with best conversion
  - Card 4: Most chosen plan

## Global elements

### Page header
HTML name (comment): <!-- Page header -->
HTML section (comment): N/A
Suggested title: Find the ideal product for your trading
Goal: acquisition
Type: global element
Suggested content:
- Main title focused on product discovery.
Suggested CTA: N/A
Data sources: N/A

### Search form
HTML name (comment): <!-- Search form -->
HTML section (comment): N/A
Suggested title: Search products
Goal: acquisition
Type: global element
Suggested content:
- Placeholder: "Search Expert Advisors, courses, add-ons, or plans".
- Scope: Expert Advisor name, course title, plan name, add-on key.
Suggested CTA: Search
Data sources: `expert_advisors.name`, `courses.title_en`, `billing_plans.name`, `addons.key`

### Filters
HTML name (comment): <!-- Filters -->
HTML section (comment): N/A
Suggested title: Catalog filters
Goal: acquisition
Type: global element
Suggested content:
- Tabs: View all, Courses, Expert Advisors, Launches.
Suggested CTA: N/A
Data sources:
- Courses -> `courses`
- Expert Advisors -> `expert_advisors`
- Launches -> `courses.published_at` and/or Expert Advisor updates

## Cards 1 (Video Courses)

### Card 1
HTML name (comment): <!-- Card 1 -->
HTML section (comment): <!-- Cards 1 (Video Courses) -->
Suggested title: Best selling course
Goal: sales
Type: course product
Suggested content:
- Top course by revenue (recent sales).
- Rating based on completions and enrollments.
- Price from the cheapest plan or add-on.
- Features: total duration, # lessons, # modules, category.
Suggested CTA: Buy course
Data sources: `courses`, `course_enrollments`, `course_lesson_progresses`, `course_lessons`, `course_plan_entitlements`, `billing_plans`, `addons`, `pay_charges`

### Card 2
HTML name (comment): <!-- Card 2 -->
HTML section (comment): <!-- Cards 1 (Video Courses) -->
Suggested title: Highest completion course
Goal: retention
Type: course product
Suggested content:
- Course with the highest completion rate.
- Show average progress and estimated time.
- Price and rating as in Card 1.
Suggested CTA: View course
Data sources: `courses`, `course_enrollments`, `course_lesson_progresses`, `course_lessons`, `course_plan_entitlements`, `billing_plans`

### Card 3
HTML name (comment): <!-- Card 3 -->
HTML section (comment): <!-- Cards 1 (Video Courses) -->
Suggested title: Most recent course
Goal: acquisition
Type: course product
Suggested content:
- Most recently published course (`published_at`).
- Initial rating based on early enrollments.
- Price from available plan.
Suggested CTA: Explore course
Data sources: `courses.published_at`, `course_enrollments`, `course_plan_entitlements`, `billing_plans`

### Card 4
HTML name (comment): <!-- Card 4 -->
HTML section (comment): <!-- Cards 1 (Video Courses) -->
Suggested title: Recommended for you
Goal: retention
Type: course product
Suggested content:
- Recommended course based on current progress (similar category or level).
- Show progress % if already enrolled.
- Price if not included in current plan.
Suggested CTA: Continue course / View course
Data sources: `course_enrollments`, `courses.category`, `course_lesson_progresses`, `course_plan_entitlements`, `billing_plans`

## Cards 2 (Digital Goods)

### Card 1
HTML name (comment): <!-- Card 1 -->
HTML section (comment): <!-- Cards 2 (Digital Goods) -->
Suggested title: Most used Expert Advisor
Goal: sales
Type: Expert Advisor product
Suggested content:
- Expert Advisor with the most active licenses.
- "Popular" badge if above threshold.
- Price from plan or add-on.
Suggested CTA: Buy Expert Advisor
Data sources: `expert_advisors`, `licenses`, `billing_plan_entitlements`, `billing_plans`, `addons`

### Card 2
HTML name (comment): <!-- Card 2 -->
HTML section (comment): <!-- Cards 2 (Digital Goods) -->
Suggested title: Expert Advisor with best 30-day Profit & Loss
Goal: sales
Type: Expert Advisor product
Suggested content:
- Expert Advisor with the best average 30-day Profit & Loss in active accounts.
- Rating based on performance and usage.
- Price from plan or add-on.
Suggested CTA: View performance
Data sources: `expert_advisors`, `broker_account_daily_results`, `licenses`, `billing_plan_entitlements`, `billing_plans`

### Card 3
HTML name (comment): <!-- Card 3 -->
HTML section (comment): <!-- Cards 2 (Digital Goods) -->
Suggested title: New tool/Expert Advisor
Goal: acquisition
Type: Expert Advisor product
Suggested content:
- Recently added Expert Advisor or tool.
- Show key benefits from `description`.
- Price from plan or add-on.
Suggested CTA: Explore Expert Advisor
Data sources: `expert_advisors`, `billing_plan_entitlements`, `billing_plans`, `addons`

### Card 4
HTML name (comment): <!-- Card 4 -->
HTML section (comment): <!-- Cards 2 (Digital Goods) -->
Suggested title: Expert Advisor with best retention
Goal: retention
Type: Expert Advisor product
Suggested content:
- Expert Advisor with the highest renewal rate.
- Rating based on retention.
- Price from plan or add-on.
Suggested CTA: View Expert Advisor
Data sources: `expert_advisors`, `pay_subscriptions`, `pay_charges`, `licenses`, `billing_plan_entitlements`, `billing_plans`

## Cards 3 (Online Events)

### Card 1
HTML name (comment): <!-- Card 1 -->
HTML section (comment): <!-- Cards 3 (Online Events) -->
Suggested title: Best selling premium session
Goal: sales
Type: one_time product
Suggested content:
- one_time plan with the most recent sales.
- Price and seats from metadata when available.
Suggested CTA: Buy access
Data sources: `billing_plans` (kind one_time), `pay_charges`, `billing_plans.metadata`

### Card 2
HTML name (comment): <!-- Card 2 -->
HTML section (comment): <!-- Cards 3 (Online Events) -->
Suggested title: Nearest upcoming session
Goal: acquisition
Type: one_time product
Suggested content:
- Next session date from `billing_plans.metadata`.
- Highlight price and time.
Suggested CTA: Reserve seat
Data sources: `billing_plans` (kind one_time), `billing_plans.metadata`

### Card 3
HTML name (comment): <!-- Card 3 -->
HTML section (comment): <!-- Cards 3 (Online Events) -->
Suggested title: Featured premium course
Goal: retention
Type: course product
Suggested content:
- Premium course with high engagement.
- Highlight recent publish date.
Suggested CTA: View premium course
Data sources: `courses`, `course_lesson_progresses`, `courses.published_at`

### Card 4
HTML name (comment): <!-- Card 4 -->
HTML section (comment): <!-- Cards 3 (Online Events) -->
Suggested title: Promotional add-on
Goal: sales
Type: add-on product
Suggested content:
- Featured add-on with best conversion.
- Promotional price if available.
Suggested CTA: Buy add-on
Data sources: `addons`, `billing_plans`, `pay_charges`

## Cards 5 (Popular Categories)

### Card 1
HTML name (comment): <!-- Card 1 -->
HTML section (comment): <!-- Cards 5 (Popular Categories) -->
Suggested title: Expert Advisors (robots)
Goal: acquisition
Type: category
Suggested content:
- Expert Advisor category for robots.
Suggested CTA: Explore
Data sources: `expert_advisors.ea_type` (ea_robot)

### Card 2
HTML name (comment): <!-- Card 2 -->
HTML section (comment): <!-- Cards 5 (Popular Categories) -->
Suggested title: Tools (EA tools)
Goal: acquisition
Type: category
Suggested content:
- Expert Advisor category for tools.
Suggested CTA: Explore
Data sources: `expert_advisors.ea_type` (ea_tool)

### Card 3
HTML name (comment): <!-- Card 3 -->
HTML section (comment): <!-- Cards 5 (Popular Categories) -->
Suggested title: Top course category
Goal: acquisition
Type: category
Suggested content:
- Category with the most active courses or enrollments.
Suggested CTA: Explore
Data sources: `courses.category`, `course_enrollments`

### Card 4
HTML name (comment): <!-- Card 4 -->
HTML section (comment): <!-- Cards 5 (Popular Categories) -->
Suggested title: Add-ons and bundles
Goal: acquisition
Type: category
Suggested content:
- Category for add-ons and Expert Advisor bundles.
Suggested CTA: Explore
Data sources: `addons`, `expert_advisor_bundles`

## Cards 6 (Trending Now)

### Card 1
HTML name (comment): <!-- Card 1 -->
HTML section (comment): <!-- Cards 6 (Trending Now) -->
Suggested title: Expert Advisor with most recent sales
Goal: sales
Type: trending product
Suggested content:
- Expert Advisor with the highest number of recent purchases.
Suggested CTA: View Expert Advisor
Data sources: `pay_charges`, `billing_plan_entitlements`, `expert_advisors`

### Card 2
HTML name (comment): <!-- Card 2 -->
HTML section (comment): <!-- Cards 6 (Trending Now) -->
Suggested title: Course with most new enrollments
Goal: acquisition
Type: trending product
Suggested content:
- Course with the highest growth in recent enrollments.
Suggested CTA: View course
Data sources: `course_enrollments`, `courses`

### Card 3
HTML name (comment): <!-- Card 3 -->
HTML section (comment): <!-- Cards 6 (Trending Now) -->
Suggested title: Add-on with best conversion
Goal: sales
Type: trending product
Suggested content:
- Add-on with the best purchase conversion.
Suggested CTA: View add-on
Data sources: `addons`, `pay_charges`, `billing_plans`

### Card 4
HTML name (comment): <!-- Card 4 -->
HTML section (comment): <!-- Cards 6 (Trending Now) -->
Suggested title: Most chosen plan
Goal: retention
Type: trending plan
Suggested content:
- Plan with the most active subscriptions.
Suggested CTA: View plan
Data sources: `billing_plans`, `pay_subscriptions`
