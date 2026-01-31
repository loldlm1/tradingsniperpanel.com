# Plan: Favicon for all landing templates + SEO copy alignment

## Goal
- Ensure all `LANDING_TEMPLATE` options (neon, fintech) use the correct favicon.
- Update SEO metadata copy to accurately reflect the product purpose and Stripe compliance language from README + Terms.

## Definition of Done
- Favicon helper covers all templates; neon uses `logo_oficial.png`, fintech uses an agreed asset.
- SEO defaults use clear, accurate copy (EN/ES) aligned with Terms and README.
- Layouts render SEO meta tags with per-page overrides and do not index dashboard/auth pages.

## Constraints
- Keep changes minimal and localized (helpers, layouts, I18n).
- Avoid financial advice/earnings claims per Stripe compliance notes.
- Use I18n for user-facing copy (EN/ES).

## Steps
1. Review README and legal Terms/Privacy copy for compliant positioning language.
2. Confirm which favicon asset to use for the fintech template (or add a new one).
3. Update favicon helper to cover all templates and wire tags in layouts.
4. Add/adjust I18n keys for SEO title/description (EN/ES) and use them as defaults.
5. Verify SEO tags and favicon in both neon and fintech templates.

## Decisions
- Always try `logo_oficial.png` per template; fall back to Rails `/icon.png` when missing.
- Keep OG/Twitter tags for link previews.
- Canonical URLs include locale prefixes for non-default locales.
- SEO copy derives from README/Terms positioning and adds a “not financial advice” disclaimer.

## Commands (PASS/FAIL)
- PASS: apply_patch app/helpers/application_helper.rb
- PASS: apply_patch config/locales/en.yml
- PASS: apply_patch config/locales/es.yml

## Open Questions
- None.
