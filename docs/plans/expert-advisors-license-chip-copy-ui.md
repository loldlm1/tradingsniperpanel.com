# Plan: Expert Advisors License/Chip/Copy UI

## Goal
Implement a consistent and reliable UX for Expert Advisors index/show by keeping guide actions aligned, standardizing status chips with the shared `filter_chip` design, and fixing license copy behavior (including explicit failure feedback).

## Definition of Done
- Guide/unlock and details CTAs render in a horizontal row across all screen sizes where both actions exist.
- Show-page status badges use the `filter_chip` visual style for all statuses (`active`, `trial`, `expired`, `revoked`, `locked`).
- License key and Copy button spacing is improved on both index and show cards.
- Copy interaction works on both index and show with success (`Copied`) and failure (`Copy failed` / `No se pudo copiar`) feedback and timed reset.
- EN/ES locale keys are present for any new copy-related feedback.
- Targeted request/service specs pass.

## Constraints
- Keep controllers thin and avoid business-logic changes.
- Reuse shared UI partials (`dashboard/shared/_filter_chip`) instead of duplicating badge styles.
- Keep copy text in I18n; no inline hardcoded user-visible strings in views.
- Avoid touching vendor template assets.

## Steps
1. Update plan-first doc and capture execution log entries.
2. Refactor show status badges to render with `filter_chip` styling.
3. Normalize guide CTA row and license spacing in EA index/show partials.
4. Replace brittle inline copy click handling with data-attribute-driven JS binding.
5. Add localized copy-failure feedback keys (EN/ES).
6. Update request specs for CTA/chip/copy wiring.
7. Run targeted specs and record pass/fail.

## Open Questions
- None.

## Execution Log (PASS/FAIL)
- PASS: Confirmed clean branch baseline (`git status --short --branch`).
- PASS: Confirmed current `status_badge_class` usage points via search.
- PASS: Refactored EA index actions/license markup in `app/views/expert_advisors/_index_card.html.erb`.
- PASS: Updated show-page status chips + show license card in `app/views/expert_advisors/show.html.erb` and `app/views/expert_advisors/_show_license_card.html.erb`.
- PASS: Reworked copy interaction in `app/javascript/dashboard.js` to data-bound handlers with secure-context fallback and failure feedback.
- PASS: Added EN/ES copy-failure locale keys in `config/locales/dashboard.en.yml` and `config/locales/dashboard.es.yml`.
- PASS: Expanded request coverage in `spec/requests/expert_advisors_spec.rb` for chip rendering and copy wiring.
- PASS: `bundle exec rspec spec/requests/expert_advisors_spec.rb spec/services/expert_advisors/index_presenter_spec.rb spec/services/expert_advisors/show_presenter_spec.rb` (20 examples, 0 failures).
