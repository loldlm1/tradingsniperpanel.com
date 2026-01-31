# Plan: SEO metadata + neon favicon

## Goal
- Use `logo_oficial.png` as the favicon when `LANDING_TEMPLATE=neon`.
- Add baseline SEO metadata (title, description, canonical, OG/Twitter) to the marketing layout.

## Definition of Done
- `logo_oficial.png` exists in assets and is used as the favicon for neon.
- Marketing layout renders SEO meta tags with sensible defaults and `content_for` overrides.
- Dashboard layout includes favicon and is marked `noindex`.

## Constraints
- Keep changes minimal and aligned with existing helper patterns.
- Use I18n for default copy where possible.

## Steps
1. Add helper methods for favicon + SEO metadata.
2. Update layouts to render favicon tags and SEO meta tags.
3. Add `logo_oficial.png` asset for neon.
4. Summarize changes and verification tips.

## Decisions
- Use `app.tagline` as the default meta description (localized via I18n).
- Default SEO image to the favicon, with per-page overrides via `content_for(:meta_image)`.
- Mark dashboard pages `noindex, nofollow` to avoid indexing authenticated UI.

## Commands (PASS/FAIL)
- PASS: cp app/assets/templates/neon/images/logo_snipe_oficial.png app/assets/templates/neon/images/logo_oficial.png
- PASS: apply_patch app/helpers/application_helper.rb
- PASS: apply_patch app/views/layouts/application.html.erb
- PASS: apply_patch app/views/layouts/dashboard.html.erb

## Open Questions
- None.
