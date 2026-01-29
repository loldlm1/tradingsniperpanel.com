# Codex workflow

- **Plan-first**: for any non-trivial change, create/update `docs/plans/<slug>.md` **before coding**.
  - Keep it short: Goal, Definition of Done, Constraints, Steps, Open Questions.
- **Clarify until aligned**: ask questions and iterate the plan until DoD + steps are clear; only then implement.
- **During execution**: update the plan with decisions + commands run (PASS/FAIL only). No long logs.
- **Keep it lightweight**: don’t paste large code blocks or tool output; reference file paths instead.
- **Done = clean**: once the feature is verified and merged, remove it from active context:
  - Move to `docs/plans/_archive/<YYYY-MM-DD>-<slug>.md` **or**
  - Delete it after copying a 5–10 line “Post-Implementation Summary” into the PR description.
  - `docs/plans/` should contain only active work.

# Skills (auto-detect)
- **Check first**: before planning, identify applicable Codex skills; if the task matches a skill’s description, use it even if not named.
- **Follow the skill**: open the relevant `SKILL.md` and follow its workflow; keep any skill-specific files/tools usage minimal and on-scope.
- **Available skills**: `rails-expert`, `frontend-design`, `unix-macos-engineer`, `find-skills`, `agent-browser`, `technical-writer`, `ui-ux-pro-max`, `mermaid-diagrams`.

# MCP (enabled)
- **Postgres MCP**: database queries via `mcp__postgres__*` (configured with `DATABASE_URL`).
- **Playwright MCP**: browser automation via `mcp__playwright__*`.
- **Fetch MCP**: readable page fetch via `mcp__fetch__*`.
- **Tavily MCP**: web search via `mcp__tavily__*`.
- **Context7 MCP**: documentation lookup via `mcp__context7__*`.
- **Disabled**: open-websearch MCP (disabled in config).

# Engineering Notes (Ruby/Rails)

- **Structure first**: keep controllers thin; push business logic to POROs/service objects under `app/services` and plain models. Use concerns sparingly—prefer explicit composition and small objects.
- **View hygiene**: extract partials/components for repeated UI (nav/footer/cards), keep helpers pure, and drive copy through `I18n` (EN/ES). Avoid inline strings—add keys under `config/locales`.
- **Pay/Stripe**: use `pay_customer default_payment_processor: :stripe` on billable models. Keep Stripe calls idempotent, store `client_reference_id` when possible, and let Pay’s webhooks sync state. Never rescue-and-forget Stripe errors; log with context and notify.
- **Referrals**: set referral cookies on marketing controllers (`set_referral_cookie`) and call `refer(user)` post sign-up. Generate referral codes on create and expose shareable URLs (respect locale in links).
- **Background work**: enqueue external API calls (Stripe sync, GeoIP updates, email) via ActiveJob/Solid Queue. Make jobs retry-safe and idempotent; guard against race conditions with optimistic locking or advisory locks when mutating billing state.
- **Error handling & logging**: raise early, rescue narrowly, and log structured context (user id, processor ids, locale). Use `Rails.logger.info/debug` for expected flows, `warn/error` for anomalies; avoid swallowing exceptions silently.
- **Testing**: prefer request/system specs for flows (auth, referrals, billing webhooks) and model specs for calculations/validations. Stub external HTTP/Stripe; keep factories lean with traits. Use I18n keys in specs to avoid hardcoded copy.
- **Performance & safety**: eager load associations for dashboards, paginate any user-facing lists, and validate inputs (strong params, presence/format on models). Cache low-churn content (docs lists) when useful; expire on deploy.
- **Assets**: keep third-party template assets under `app/assets/templates/...` and avoid mutating vendor files. Add new CSS/JS via Tailwind (tailwindcss-rails) or importmap pins; prefer small, explicit imports over global packs. Avoid inline `<style>`/`<script>` in views—extract to asset files and include with the appropriate tags.
- **Internationalization**: detect locale via params/session/GeoIP/Accept-Language; persist user preference. Never concatenate translated strings; use interpolation and provide fallbacks (`I18n.fallbacks = [:en]`).
- **Reference docs**: see `docs/database_model_reference.md` for the data model/API surface and `docs/cruip_template_guide.md` for the Cruip (Neon/Mosaic) component catalogue and JS hooks before adding features.
