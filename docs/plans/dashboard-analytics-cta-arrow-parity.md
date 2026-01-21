# Dashboard Analytics CTA Arrow Parity

Goal
- Fix CTA arrow rendering so dashboard links match the Mosaic template using a minimal, low-risk change.

Definition of Done
- Root cause confirmed (copy content, font/ligature, CSS/pseudo-element, or helper/component behavior).
- Fix approach agreed (copy change, icon insertion, or styling) and documented.
- All dashboard copy that uses arrow tokens renders with the right-arrow glyph across locales.

Constraints
- Use I18n for copy; do not hardcode strings in views.
- Avoid inline styles/scripts; follow existing view/asset structure.
- Do not modify vendor template assets.
- Keep changes small; avoid large refactors or font stack changes.

Possible Causes (Hypotheses)
- CTA copy uses ASCII `->` while Mosaic renders a right-arrow glyph (e.g., via font ligature or `&rarr;` in copy).
- Different font stack or font-feature settings remove arrow ligature behavior.
- CTA link styling differs (missing pseudo-element or icon markup).
- A helper/partial alters CTA text or strips special characters.

Steps
1. Scan dashboard locales and views for `->` usage and confirm CTA arrow text is sourced from I18n.
2. Choose the minimal fix (replace `->` with right-arrow glyph in translations) and validate it does not require font changes.
3. Update all dashboard locale entries that use `->` across EN/ES.
4. QA analytics and other dashboard areas that display arrow text.

Decisions
- Use a right-arrow glyph in translations (no font stack changes).
- Apply across all dashboard locales (EN/ES now; standardize everywhere in dashboard locale files).
- Keep the fix minimal: translation updates only.

Open Questions
- None.

Commands (PASS/FAIL only)
- `apply_patch` (PASS)
- `rg -n "->" config/locales app/views` (FAIL)
- `rg -n -- "->" config/locales app/views` (PASS)
- `rg -n -- "[^\\x00-\\x7F]" config/locales/dashboard.en.yml` (PASS)
- `sed -n '530,580p' config/locales/dashboard.en.yml` (PASS)
- `sed -n '680,720p' config/locales/dashboard.en.yml` (PASS)
- `sed -n '530,580p' config/locales/dashboard.es.yml` (PASS)
- `sed -n '690,710p' config/locales/dashboard.es.yml` (PASS)
- `apply_patch` (PASS)
- `rg -n -- "->" config/locales` (FAIL)
