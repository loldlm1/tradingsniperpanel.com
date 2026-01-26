# Full-stack Engineer (Default)

Purpose:
- Deliver end-to-end features across DB, backend, UI, and tests with minimal risk.

When to use:
- Default for most feature requests that touch multiple layers.

When NOT to use:
- Pure backend changes with no UI (use `backend-rails-pg.md`).
- Pure UI/Cruip refactors or visual work (use `frontend-cruip.md`).
- Bugfix/regression-only work (use `bugfix-qa.md`).

Inputs required:
- Acceptance criteria and Definition of Done.
- Designs or template source (Cruip pages) if UI changes are expected.
- Data model expectations (new fields, tables, entitlements, access rules).
- Affected locales (EN/ES) and copy requirements.
- External integrations (Stripe/Pay, OAuth, GeoIP) and constraints.

Step-by-step checklist:
1) Clarify scope and risks
- Confirm acceptance criteria, edge cases, and affected user roles.
- Identify if migrations, background jobs, or external API calls are required.

2) Locate guidance and prior art
- Read `AGENTS.md`, `docs/database_model_reference.md`, and `docs/cruip_template_guide.md`.
- Scan similar flows in controllers/services/views; reuse patterns and partials.

3) Plan the work
- Define minimal-diff changes and dependencies (DB, service objects, UI, tests).
- Note risky areas (billing, referrals, locale detection, access control).

4) Implement (layered)
- Data: add reversible migrations, indexes, and constraints where needed.
- Backend: keep controllers thin, move logic to `app/services` or models.
- UI: reuse Cruip sections and keep HTML comment blocks intact.
- I18n: add EN/ES keys in `config/locales`, avoid inline strings.
- Assets: do not edit vendor templates; use Tailwind overrides or small assets.
- Background work: enqueue external calls via ActiveJob; make jobs idempotent.
- Logging: log structured context; avoid swallowing exceptions.

5) Tests
- Add request/system specs for flows and model specs for calculations.
- Stub external HTTP/Stripe; use I18n keys in specs.

6) Verify
- Run targeted tests, and full suite when reasonable.
- Smoke-check UI paths; use Playwright MCP if UI is affected.

7) Summarize
- Document changes, commands run, and verification status.
- Call out follow-ups or risks.

Tool/MCP guidance:
- Postgres MCP: inspect schema or run safe SELECTs (no writes).
- Playwright MCP: smoke-test UI flows and regression scenarios.
- Context7 MCP: lookup Rails/gem APIs or version-specific behavior.
- Fetch/Search MCPs: only for external references; prefer official docs.

Verification commands (adjust as needed):
- `bin/rails db:migrate`
- `bin/rails db:prepare`
- `bundle exec rspec`
- `COVERAGE=true bundle exec rspec`
- `bin/dev` (UI smoke)
- `npm run dev:css`

Definition of Done:
- Acceptance criteria met with minimal diffs.
- No inline copy; EN/ES I18n keys in place.
- Controllers remain thin; services cover business logic.
- Tests added/updated and passing for affected areas.
- Risks and follow-ups are documented.
