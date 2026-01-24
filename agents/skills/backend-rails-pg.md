# Back-end Engineer (Rails/PG Specialist)

Purpose:
- Deliver API, data modeling, background jobs, and performance work safely in Rails/Postgres.

When to use:
- New endpoints, data model changes, background jobs, billing/referrals logic, or performance work.

When NOT to use:
- UI-heavy work or Cruip layout updates (use `frontend-cruip.md`).
- Bugfix-first efforts needing repro + regression focus (use `bugfix-qa.md`).

Inputs required:
- API contract or endpoint requirements.
- Data changes (tables/columns/indexes/constraints) and backfill needs.
- Access control and roles impacted.
- External integration details (Stripe/Pay, OAuth, GeoIP).

Rules and conventions:
- Migrations must be reversible and safe; add indexes/constraints where appropriate.
- Avoid N+1: use `includes`, `preload`, or `eager_load` as needed.
- Keep controllers thin; push logic into services or POROs.
- Use ActiveJob/Solid Queue for external calls; jobs must be idempotent.
- Log structured context; never rescue-and-forget Stripe errors.

Step-by-step checklist:
1) Model and data design
- Map entities to existing tables in `docs/database_model_reference.md`.
- Add migrations with rollback paths, constraints, and indexes.
- Document any data backfill or one-off maintenance steps.

2) Service-layer implementation
- Implement core logic in `app/services` or models, not controllers.
- Guard against race conditions (optimistic/advisory locks if needed).
- Keep Stripe/Pay actions idempotent and let webhooks sync state.

3) Performance and safety
- Preload associations for dashboard queries.
- Paginate user-facing lists.
- Validate inputs with strong params and model validations.

4) Tests
- Add request specs for endpoints; model specs for calculations/validations.
- Stub external services; avoid hardcoded copy in specs (use I18n keys).

5) Verification
- Run migrations locally and verify schema changes.
- Run targeted request/spec suites.

Tool/MCP guidance:
- Postgres MCP: verify schema or run SELECTs (read-only, no writes).
- Context7 MCP: reference Rails/gem APIs and version-specific behavior.
- Fetch/Search: only for external references when needed.

Verification commands (adjust as needed):
- `bin/rails db:migrate`
- `bin/rails db:rollback`
- `bundle exec rspec spec/requests/...`
- `bundle exec rspec spec/models/...`

Definition of Done:
- Data changes are reversible, indexed, and constrained appropriately.
- Services encapsulate business logic; controllers remain thin.
- No N+1 regressions; lists are paginated.
- Tests cover new behavior; critical flows verified.
