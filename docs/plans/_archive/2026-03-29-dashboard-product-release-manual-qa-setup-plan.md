# Plan: Dashboard Product Release Manual QA Setup

**Generated**: 2026-03-29
**Status**: Completed

## Goal
Create a dedicated manual-QA account with real subscribed access, publish a grouped release batch containing at least 2 EA updates, 1 add-on, and 1 course through the admin release flow, and hand the account credentials to the user for manual verification.

## Definition of Done
- A fresh trader QA account exists with login credentials ready to share.
- The account has real access to at least 2 EAs and 1 course relevant to the release batch.
- A grouped `ProductRelease` batch is published through the admin release action, not by direct DB insertion.
- The published release contains at least 4 visible items for the QA account:
  - 2 EA updates
  - 1 add-on addition
  - 1 course addition
- Admin publish flow is confirmed working for this scenario.

## Constraints
- Prefer real app flows and persisted records over temporary test doubles.
- Keep existing seeded QA users intact; use a dedicated new manual-QA account.
- Do not rely on fake notification rows when the admin publish button can exercise the intended path.

## Steps
1. Inspect subscription/access helpers and pick the minimal way to provision a new subscribed trader account with EA/course access.
2. Prepare publishable changes against tracked subjects so the release diff service will detect:
   - two EA updates
   - one newly available add-on
   - one newly available course
3. Run the admin publish action and verify the created release batch contents.
4. Confirm the dedicated QA account sees the grouped release and provide credentials plus a short manual-QA checklist.

## Open Questions
- None at start; use the local environment and current seeded catalog unless a provisioning blocker appears.

## Decisions
- Use the existing `pro` subscription tier for the QA trader because it grants multiple real EA entitlements and course access without over-provisioning.
- Establish the current catalog as the release baseline by writing `ProductReleaseSnapshot` records directly before staging the new QA release items.
- Publish the actual grouped release through the real ActiveAdmin publish button after the staged changes are in place.
- Seed deterministic dev-only EA license encoder keys inside the setup script when the local env does not provide real keys.
- Keep the manual QA account on a fixed email so the user can reuse the same credentials on reruns, while the staged add-on/course records use timestamped keys so each rerun still produces a clean 4-item diff.
- Fix the ActiveAdmin `ProductRelease` show table so the publish redirect lands on a valid detail page after the real button click.

## Commands
- `PASS` `bundle exec rails runner 'puts({releases: ProductRelease.count, items: ProductReleaseItem.count, snapshots: ProductReleaseSnapshot.count, dismissals: ProductReleaseDismissal.count}.inspect); puts ProductReleaseSnapshot.group(:product_kind).count.inspect; puts({eas: ExpertAdvisor.active.count, addon_products: MarketplaceProduct.active.includes(billing_plan: :addon).select { |p| p.billing_plan&.addon.present? }.count, courses: Course.published.count}.inspect)'`
- `PASS` `bundle exec rails runner 'plans = BillingPlan.subscription.active.order(:sort_order, :amount_cents); puts plans.map { |p| [p.id, p.key, p.tier, p.interval_key] }.inspect; puts "EA entitlements:"; ExpertAdvisor.active.includes(:billing_plan_entitlements, :billing_plans).each { |ea| puts({name: ea.name, tiers: ea.subscription_tiers}.inspect) }; puts "Course entitlements:"; Course.published.includes(:course_plan_entitlements, :billing_plans).each { |course| puts({title: course.title_en, tiers: course.subscription_tiers}.inspect) }'`
- `PASS` `bundle exec rails runner 'puts User.order(:id).pluck(:id, :email, :role, :preferred_locale).map(&:inspect)'`
- `PASS` `bundle exec rails runner script/product_release_manual_qa_setup.rb`
- `PASS` `bundle exec rails runner 'user = User.find_by!(email: "qa.product.release@example.com"); eas = Licenses::AccessibleExpertAdvisors.new(user: user).call.select(&:accessible).map { |entry| entry.expert_advisor.name }; courses = Courses::AccessibleCourses.new(user: user).call.select(&:accessible).map { |entry| entry.course.title_en }; puts({accessible_eas: eas, accessible_courses: courses}.inspect)'`
- `PASS` `bundle exec rails runner 'tracked = ProductReleases::CatalogSnapshotBuilder.new.call; snapshot_map = ProductReleaseSnapshot.all.index_by { |snapshot| [snapshot.subject_type, snapshot.subject_id, snapshot.product_kind] }; changed = tracked.filter_map do |tracked_subject| snapshot = snapshot_map[tracked_subject.snapshot_key]; action = case tracked_subject.product_kind; when "expert_advisor" then next unless snapshot.present?; next if snapshot.signature == tracked_subject.signature; "updated"; when "addon", "course" then next if snapshot.present?; "added"; end; {kind: tracked_subject.product_kind, action: action, title: tracked_subject.title_en}; end; puts changed.inspect'`
- `PASS` `bundle exec rspec spec/requests/admin_product_releases_spec.rb spec/requests/dashboard_product_releases_spec.rb`
- `PASS` `git diff --check`
