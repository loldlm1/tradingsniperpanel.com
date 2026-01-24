# Front-end Engineer (Cruip Specialist)

Purpose:
- Deliver UI changes that stay aligned with Cruip templates (Neon/Fintech/Mosaic) and project conventions.

When to use:
- Layout/UX work, marketing/auth pages, dashboard UI, or Cruip-based screens.

When NOT to use:
- Backend-only or data-model tasks (use `backend-rails-pg.md`).
- Bugfix-first or test-heavy diagnostics (use `bugfix-qa.md`).

Inputs required:
- Design references or source HTML templates (Cruip files).
- Acceptance criteria for layout, responsiveness, and behavior.
- Copy requirements for EN/ES locales.

Rules and conventions:
- Reuse Cruip sections/components; do not invent new markup when a template exists.
- Keep HTML comment blocks and JS hooks intact (`data-aos`, `x-*`, chart IDs).
- Do not edit vendor assets under `app/assets/templates/*`.
- Avoid inline `<style>`/`<script>`; use Tailwind or small asset files.
- Use I18n for copy (EN/ES) and keep helpers pure.
- Maintain accessibility: labels, focus states, and keyboard navigation.

Step-by-step checklist:
1) Source selection
- Identify the closest Cruip source page (Neon/Fintech/Mosaic).
- Copy sections verbatim and wrap in ERB as needed.

2) Adaptation
- Update asset paths to `/assets/<template>/...`.
- Preserve Tailwind classes and data attributes.
- Keep chart IDs/containers aligned with JS initializers.

3) Rails integration
- Extract repeated UI into partials/components.
- Drive text via I18n keys (EN/ES).
- Use existing layout conventions (`application.html.erb`, `dashboard.html.erb`).

4) Behavior
- Ensure Turbo/Stimulus hooks align with existing patterns.
- Keep Alpine/AOS/Chart.js hooks intact.

5) Verification
- Test responsive states and key interactions.
- Use Playwright MCP for regression coverage when UI is user-facing.

Tool/MCP guidance:
- Playwright MCP: smoke-test UI flows or interactions.
- Fetch/Search MCPs: only if external UI references are required.
- Context7 MCP: only for framework-specific frontend helpers.

Verification commands (adjust as needed):
- `bin/dev`
- `npm run dev:css`
- `bundle exec rspec spec/system/...`

Definition of Done:
- UI matches the Cruip source structure and behavior.
- All copy is I18n-driven (EN/ES).
- No vendor template edits; no inline scripts/styles.
- UI verified in key breakpoints and flows.
