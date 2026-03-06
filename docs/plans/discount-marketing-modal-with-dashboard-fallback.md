# Discount Marketing Modal With Dashboard Fallback

## Goal
Replace the current top discount banner with a clearer marketing modal that highlights the Stripe discount code, while keeping the existing env-driven logic and minimizing UI churn.

## Pivot (2026-03-06)
- User requested moving modal placement from landing (`/`) to dashboard main path (`/dashboard`) because landing visual integration is not acceptable.

## Definition of Done
- The landing page (`/`) does not render the discount marketing modal.
- A Mosaic-styled discount modal is shown on dashboard main path (`/dashboard`) only when `DISCOUNT_BANNER_CODE` and `DISCOUNT_BANNER_PERCENT` resolve to a valid payload.
- Modal behavior remains one-per-tab-session, with escape/outside click close.
- Dashboard CTA points to a dashboard-relevant path (`/dashboard/plans`).
- EN/ES copy remains I18n-driven for the active modal.
- Request specs validate presence on dashboard when env values are valid and absence when invalid.
- Audit Gate reports PASS for code pattern/efficiency, behavior alignment, and tests context.

## Constraints
- Keep the existing env contract (`DISCOUNT_BANNER_CODE`, `DISCOUNT_BANNER_PERCENT`) and parser service behavior.
- Keep controllers thin and place UI logic in partial(s), with no inline script blocks.
- Keep copy under `config/locales/en.yml` and `config/locales/es.yml`.
- Keep scope limited to discount campaign UI behavior and related tests.
- Reuse dashboard/Mosaic visual patterns for modal layout and buttons.

## Steps
1. Remove landing modal render from Neon home and keep home request expectations aligned.
2. Expose discount payload in `DashboardsController#show` using existing `Marketing::DiscountBanner` service.
3. Add a dashboard-scoped modal partial using Mosaic modal structure and dashboard button styles, with CTA to `dashboard_plans_path`.
4. Render dashboard modal on `app/views/dashboards/show.html.erb` when payload is present.
5. Keep one-per-tab-session behavior using `sessionStorage` campaign key in Alpine state.
6. Update request specs for dashboard presence/absence and home absence.
7. Run targeted specs and record PASS/FAIL in this plan.
8. Run Audit Gate and record final PASS/FAIL in this plan.

## Open Questions
- None. Confirmed with user on 2026-03-06.

## Decisions
- Investigate Mosaic modal building blocks first, then implement with minimal custom behavior.
- Pivot applied: modal placement is dashboard main (`/dashboard`), not landing (`/`).
- Keep discount payload env-driven and do not add Stripe coupon automation in this change.
- Modal will auto-open once per browser tab session (using client-side session state).
- Session reset trigger is tab/window close (or full browser close when previous session is not restored).
- Dashboard fallback became the primary implementation per user request.

## Command Log (PASS/FAIL)
- `PASS` `rg --files docs/plans app/views app/controllers app/services | sed -n '1,220p'`
- `PASS` `rg -n "discount_banner|DISCOUNT_BANNER|Marketing::DiscountBanner|modal|dialog" app config docs/plans mosaic-html -S`
- `PASS` `sed -n '1,260p' app/controllers/pages_controller.rb`
- `PASS` `sed -n '1,260p' app/services/marketing/discount_banner.rb`
- `PASS` `sed -n '1,260p' app/views/templates/neon/pages/home.html.erb`
- `PASS` `sed -n '1,220p' app/views/shared/_discount_banner.html.erb`
- `PASS` `sed -n '1,260p' app/views/layouts/application.html.erb`
- `PASS` `sed -n '1060,1225p' mosaic-html/component-modal.html`
- `PASS` `sed -n '700,860p' mosaic-html/dashboard_marketplace_index.html`
- `PASS` `sed -n '1,240p' spec/services/marketing/discount_banner_spec.rb`
- `PASS` `sed -n '1,240p' spec/requests/home_pricing_cta_spec.rb`
- `PASS` `rg -n "landing\\.neon\\.discount_banner|_discount_banner|discount_modal" app spec config/locales -S`
- `PASS` `bundle exec rspec spec/services/marketing/discount_banner_spec.rb spec/requests/home_pricing_cta_spec.rb`
- `PASS` `rg -n "RSpec.describe \\\"Dashboard|dashboard_path|DashboardsController|sign_in .*dashboard" spec -S`
- `PASS` `sed -n '1,260p' spec/requests/dashboard_spec.rb`
- `PASS` `sed -n '1,260p' app/controllers/dashboards_controller.rb`
- `PASS` `sed -n '1,260p' app/views/dashboards/show.html.erb`
- `PASS` `sed -n '1,320p' config/locales/dashboard.en.yml`
- `PASS` `sed -n '1,320p' config/locales/dashboard.es.yml`
- `PASS` `bundle exec rspec spec/services/marketing/discount_banner_spec.rb spec/requests/home_pricing_cta_spec.rb spec/requests/dashboard_spec.rb`

## Audit Gate
- `PASS` Code pattern and efficiency: env parsing remains isolated in `Marketing::DiscountBanner`; dashboard controller adds a single show-scoped assignment; modal logic is contained in a dashboard partial with existing Mosaic patterns.
- `PASS` Feature behavior and goal alignment: landing no longer renders the discount modal; dashboard main (`/dashboard`) renders the discount modal only with valid env payload; modal closes on escape/outside click and retains one-per-tab-session behavior.
- `PASS` Tests context: home request spec now asserts absence on `/`; dashboard request spec asserts presence/absence by env validity; discount parser service spec remains green. Gap noted: no JS system spec for runtime `sessionStorage` behavior.
