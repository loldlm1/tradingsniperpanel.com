# Discount Marketing Modal With Dashboard Fallback

## Goal
Replace the current top discount banner with a clearer marketing modal that highlights the Stripe discount code, while keeping the existing env-driven logic and minimizing UI churn.

## Definition of Done
- The top discount banner is removed from the Neon landing page (`/`).
- A marketing modal is shown on `/` only when `DISCOUNT_BANNER_CODE` and `DISCOUNT_BANNER_PERCENT` resolve to a valid payload.
- Modal copy and CTA use I18n (EN/ES) and match the current landing visual language.
- The modal does not cover or break the landing header layout.
- A Mosaic-compatible modal pattern is reused (Alpine + backdrop + dialog transitions + escape/outside-close).
- A documented decision gate is applied:
  - Keep landing modal if implementation remains small and visually aligned.
  - Move to dashboard placement if landing integration is visually off or requires unexpectedly large changes.
- Specs are updated to validate visibility conditions and new rendered content.
- Audit Gate reports PASS for code pattern/efficiency, behavior alignment, and tests context.

## Constraints
- Keep the existing env contract (`DISCOUNT_BANNER_CODE`, `DISCOUNT_BANNER_PERCENT`) and parser service behavior.
- Keep controllers thin and place UI logic in partial(s), with no inline script blocks.
- Keep copy under `config/locales/en.yml` and `config/locales/es.yml`.
- Keep scope limited to discount campaign UI behavior and related tests.

## Steps
1. Confirm reusable Mosaic modal pattern from `mosaic-html/component-modal.html` and `mosaic-html/dashboard_marketplace_index.html` for Alpine behavior and accessibility attributes.
2. Build a shared modal partial for marketing pages (replace current banner partial usage) and wire it in the Neon home view.
3. Reuse current discount payload source (`Marketing::DiscountBanner`) so visibility rules stay env-driven and deterministic.
4. Add/adjust locale keys for modal title/body/cta/close labels in EN/ES; remove stale banner-only keys if fully unused.
5. Run decision gate after local visual check:
   - If landing modal is aligned and change size is small, keep on `/`.
   - If not aligned or too invasive, move placement to dashboard (`dashboards/show` first candidate) with Mosaic-native styling.
6. Update request/spec coverage for valid/invalid env scenarios and modal rendering markers.
7. Run targeted specs and record PASS/FAIL in this plan.
8. Run Audit Gate and record final PASS/FAIL in this plan.

## Open Questions
- None. Confirmed with user on 2026-03-06.

## Decisions
- Investigate Mosaic modal building blocks first, then implement with minimal custom behavior.
- Prefer landing-page modal on `/`; fallback to dashboard only if alignment or effort is not acceptable.
- Keep discount payload env-driven and do not add Stripe coupon automation in this change.
- Modal will auto-open once per browser tab session (using client-side session state).
- Session reset trigger is tab/window close (or full browser close when previous session is not restored).
- If landing modal is visually aligned on `/`, no dashboard fallback implementation is required.
- Landing implementation remained scoped and aligned, so dashboard fallback was not implemented.

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

## Audit Gate
- `PASS` Code pattern and efficiency: controller/service contract stayed unchanged; UI moved from a top banner partial to a dedicated modal partial with contained Alpine state and no extra controller branching.
- `PASS` Feature behavior and goal alignment: banner removed from `/`, modal is env-gated by existing payload resolution, includes discount code highlight, closes on escape/outside click, and uses session storage for once-per-tab-session display.
- `PASS` Tests context: request spec assertions updated for modal rendering and invalid-env hiding; existing discount parser service specs still pass. Gap noted: no JS system spec for runtime session reset behavior.
