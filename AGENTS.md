<!-- token-saver-orchestrator:rtk:start -->
## Token Saver: RTK

For Codex coding work, prefer `rtk` for noisy shell output before raw commands:
- Use `rtk git status`, `rtk git diff`, `rtk git log`, `rtk grep`, `rtk find`, `rtk ls`, `rtk test <cmd>`, and RTK wrappers for test/lint/build output when available.
- Keep exact raw output only when it matters: subtle compiler errors, security diagnostics, one-off failures, or when a compressed result omits needed evidence.
- If compressed output is insufficient, rerun the smallest raw command needed and mention why.
- Do not store full logs in chat. Save raw artifacts to files and summarize paths plus first useful failure lines.
<!-- token-saver-orchestrator:rtk:end -->

<!-- token-saver-orchestrator:ponytail-lite:start -->
## Token Saver: Ponytail Lite

For normal Codex coding tasks, default to minimal code without reducing correctness:
- Build only what was requested and needed for acceptance criteria.
- Prefer deletion, stdlib/platform-native features, existing dependencies, and existing local helpers before adding abstractions or packages.
- Keep changes scoped to the touched behavior; avoid speculative architecture and unrelated refactors.
- Bypass this rule for research, code review, architecture, security, DevOps, premium UI, documents, and any task that asks for robust output.
- Never save tokens by skipping validation, accessibility, data-loss protections, rollback notes, or production readiness when they matter.
<!-- token-saver-orchestrator:ponytail-lite:end -->

# Trading Sniper Panel Agent Rules

Use this file for project-specific invariants. Keep reusable framework guidance
in installed Codex skills, Mosaic porting procedure in
`.agents/skills/mosaic-html-rails`, and deeper architecture or operational
rationale in `docs/`.

## Instruction Precedence

When instructions conflict, use this order:

1. Explicit user instruction for the current task.
2. This `AGENTS.md` file.
3. Project documentation in `docs/` and `README.md`.
4. `rails-production-engineering` and narrower applicable installed skills.
5. Existing local code conventions.
6. Official/current documentation for the installed version.

## Current Skill Routing

Use the smallest skill set that covers the task. Read each selected `SKILL.md`
before planning or editing, and load only the references required by that skill.

- `rails-production-engineering`: base authority for Rails implementation,
  review, refactoring, migrations, jobs, APIs, security, tests, and release
  readiness.
- `.agents/skills/mosaic-html-rails`: authenticated Mosaic dashboard, settings,
  billing, plans, support, FAQ, and Mosaic auth/account porting.
- `premium-product-ui-builder`: user-visible UX/UI quality, accessibility,
  responsive behavior, forms, states, dashboard polish, and design-system work.
- `typescript-production-engineering`: substantial JavaScript/TypeScript,
  Stimulus, browser protocol, asset, or behavior-preserving frontend refactors.
- `postgres-production-engineering`: PostgreSQL schema/SQL, constraints,
  indexes, query plans, locking, backfills, roles, backup/restore, and database
  operational work beyond ordinary Rails model changes.
- `devops-release-production-engineering`: Docker, Kamal, Ubuntu/VPS, secrets,
  environment variables, health checks, rollback, logs, backups, systemd,
  proxy, and release runbooks.
- `mql5-production-engineering`: `.mq5`/`.mqh`, EA licensing clients, trade
  lifecycle, magic numbers, broker/risk controls, MetaEditor, and Strategy
  Tester work.
- `token-efficient-web-qa`: browser smoke/E2E QA, Playwright setup, compact
  failure triage, screenshots/traces, and browser environment troubleshooting.
- `ai-agent-app-production-engineering`: only when adding or reviewing actual
  OpenAI/agent features, tool calls, MCP integration, prompts, evals, traces, or
  model-visible data boundaries in this app.
- `token-saver-orchestrator`: RTK-first output, Ponytail Lite, Headroom policy,
  compaction handling, and token-saver metrics. It never overrides quality or
  safety gates.
- `create-plan`: only for a user-requested concise, read-only plan in chat.
- `planner`: only when the user explicitly invokes `$planner` for a saved,
  phased, sprint-based plan. Never invoke it implicitly.

Do not reference or wait for skills that are not installed. If no narrower
skill applies, use this file, the Rails skill, local code, and current official
documentation.

## Local-First Workflow

- Inspect `git status --short`, the current branch, relevant existing diffs,
  `Gemfile.lock`, configuration, routes, nearby code, nearby specs, and project
  docs before meaningful edits.
- Preserve user changes in a dirty worktree. Ignore unrelated changes; stop if
  an unexpected concurrent edit overlaps the files being changed.
- Follow versions in the Ruby/project lockfiles and the established Rails 8,
  Propshaft, importmap, Stimulus, Tailwind v4, RSpec, Sidekiq, Pay/Stripe, and
  PostgreSQL conventions.
- Prefer local binstubs, scripts, helpers, patterns, dependencies, and template
  assets over new abstractions or tooling.
- Treat routes, JSON shapes/error codes, job arguments, DOM IDs/classes,
  Turbo/Stimulus hooks, data attributes, JS events, and storage keys as public
  contracts until proven private.
- Keep normal implementation plans concise. Create a durable file under
  `docs/plans/` only when the user requests one or the work needs multi-step,
  high-risk, or cross-session coordination. Keep active plans out of the
  archive until completion, then archive or delete them.

## Saved Plan Execution

- A `$planner` planning turn changes only its plan artifact; it does not begin
  implementation or create the proposed commits.
- When the user later authorizes execution, read the planner execution-state
  reference, initialize active-plan state, execute sprints strictly in order,
  validate each sprint, and create exactly one sprint-specific commit before
  advancing.
- Do not skip sprints or begin later work while the current sprint has failed
  validation, unresolved risk, or stale assumptions.
- For non-planner work, create commits only when the user explicitly requests
  them. Never amend, squash, rebase, or force-push without explicit approval.

## Research And External Tools

Use external tools only when local files, installed skills, and project docs are
insufficient. Stop researching once the implementation decision is clear.

1. Inspect local code, tests, lockfiles, configs, docs, and installed gem source.
2. Use version-aware official documentation for Rails, gems, Hotwire, Stripe,
   Pay, deployment, PostgreSQL, MQL5, or OpenAI behavior that may have changed.
3. Use Context7 or another docs lookup only for the exact package/topic needed.
4. Use broader web search only for current vendor changes, advisories, or
   compatibility facts that official/local sources do not answer.
5. Use browser or database tools only for targeted evidence unavailable from
   deterministic local checks.

Never send secrets, raw tokens, credentials, authorization headers, license
keys, private customer/billing data, webhook secrets, `.env` values, private
logs, proprietary EA parameters, or internal URLs to external tools. Do not
fetch private, metadata, admin, signed, or credential-bearing URLs with
networked research tools unless the user explicitly requests it and the task
cannot be completed safely another way. Local browser QA may use the app's
localhost test/development URL with fake or seeded data.

## Project Identity

- App: Trading Sniper Panel; Rails namespace: `TradingsniperpanelCom`.
- Product: SaaS marketing and management for MQL5 Expert Advisors, tools,
  indicators, scripts, courses, marketplace assets, subscriptions, licensing,
  partner referrals, and payouts.
- Public surface: localized marketing, authentication, legal, pricing, and
  checkout for `tradingsniperpanel.com`.
- Authenticated surface: Cruip Mosaic dashboard for licenses, analytics,
  marketplace, courses, billing, support, settings, releases, and partners.
- Admin: ActiveAdmin for catalog, billing, partner, release, and content work.
- Database: PostgreSQL. Tests: RSpec with FactoryBot.
- Jobs: Active Job uses Sidekiq. Solid Queue is installed but is not the current
  adapter; do not switch backends without an explicit migration plan.
- Payments: Pay with Stripe as the default processor.
- Authentication: Devise, Google OAuth, user roles, and ActiveAdmin boundaries.
- Localization: English and Spanish with route/session/user preference,
  detection, and `I18n.fallbacks = [:en]`.
- Assets: Propshaft, importmap, Stimulus, Tailwind v4 through
  `tailwindcss-rails` and Node CLI, with Cruip assets under
  `app/assets/templates/...`.

## Public Contracts And Security

- Keep licensing and entitlement decisions server-authoritative. Never trust
  browser, EA client, or admin form state for ownership, subscriptions,
  add-ons, trials, or marketplace access.
- Preserve the documented REST JSON v1 contracts for
  `/api/v1/licenses/verify`, `/api/v1/licenses/heartbeat`,
  `/api/v1/licenses/instance_magic`, and
  `/api/v1/broker_accounts/daily_results` unless a versioned change updates
  implementation, `docs/database_model_reference.md`, EA clients, and tests
  together.
- Preserve documented API error codes, response shapes, signed-32-bit-safe
  magic-number behavior, online-seat semantics, and idempotency.
- Never expose license keys, `encrypted_key`, Stripe or webhook secrets, OAuth
  secrets, Tawk.to secure-mode keys, MaxMind license data, session tokens,
  credentials, or private customer/billing data in HTML, JavaScript, JSON not
  intended for that authenticated caller, data attributes, URLs, logs, errors,
  traces, telemetry, screenshots, or external tool requests.
- Enforce ownership, role, entitlement, and admin boundaries in the domain or
  query layer where practical, not only in controllers or views.
- Use integer cents and decimal-safe calculations for money. Never use floats
  for money or exact decimal values.
- Keep Stripe operations idempotent, store processor/client references, and let
  Pay webhooks synchronize processor state.
- Preserve referral attribution: set referral cookies on marketing entry,
  link referrals after sign-up, generate referral codes, keep share links
  locale-aware, and preserve partner depth, payout transitions, and commission
  idempotency.
- Prevent duplicate commissions, payouts, license grants, charges, purchases,
  and access when billing or payout states change.
- Never rescue-and-forget Stripe, Pay, OAuth, email, GeoIP, licensing, or
  external-provider failures. Handle narrowly with structured, non-sensitive
  context and re-raise or transition explicitly when required.
- Keep external HTTP, Stripe sync, GeoIP, email, release notifications, AI model
  calls, and bulk work out of request hot paths unless intentionally synchronous
  and covered by tests.

## Domain Boundaries

Use `docs/database_model_reference.md` as the high-signal persisted model, API,
service, and data-flow map. Keep changes inside the smallest relevant context:

- `Accounts/Auth`: Devise, OAuth, terms, roles, locale, admin access.
- `Catalog`: EAs, bundles, add-ons, courses, lessons, marketplace, releases.
- `Licensing`: keys, verification, heartbeat, online sessions, broker accounts,
  lane/instance magic numbers, daily results, and MQL5 client contracts.
- `Billing`: plans, entitlements, Pay/Stripe, checkout, portal, manual billing.
- `Referrals/Partners`: attribution, memberships, commissions, payouts.
- `Dashboard`: authenticated analytics, downloads, content, billing, support,
  settings, releases, and partner workflows.
- `Admin`: ActiveAdmin operational catalog, billing, partner, release, content.
- `Localization/Branding`: EN/ES, `LANDING_TEMPLATE`, support chat, SEO, mailers.

## Rails Implementation Rules

- Keep controllers thin: authentication/authorization, parameter
  normalization, orchestration, and response shape.
- Put business rules in the local model/domain/service/policy/command/query
  boundary. Prefer explicit current-user/current-role inputs over raw IDs for
  sensitive operations.
- Use validations plus database constraints, unique indexes, transactions,
  locks, idempotent jobs, and retry-safe services for durable invariants.
- Review migrations for current production data, locks, defaults, indexes,
  backfills, reversibility, rolling deploys, and rollback. Use the PostgreSQL
  skill for engine-level or operational database work.
- Keep API controllers JSON-only where expected. Validate payload shape before
  domain calls and keep error normalization stable.
- Use Active Job for durable Stripe/Pay sync, GeoIP, email, release, payout,
  licensing maintenance, and bulk/admin work. Jobs must be idempotent and
  retry-safe.
- Keep gated Active Storage downloads behind ownership and entitlement checks.
- Use Pagy or the established pattern for growing lists and eager-load
  associations on dashboard/admin hot paths.
- Drive durable UI copy through I18n in EN/ES. Use interpolation, never string
  concatenation, and account for longer Spanish copy.
- Keep helpers pure and presentation-focused. Prefer explicit composition over
  broad concerns and avoid speculative layers.
- For ActiveAdmin, preserve authorization, ransack allowlists, permitted params,
  safe scopes, and operational auditability.
- For Pay/Stripe, keep `pay_customer default_payment_processor: :stripe` on
  billable models, checkout/session idempotency, and webhook-driven sync.
- For referral/partner work, preserve refer callbacks, membership depth,
  discount resolution, payout transitions, and notification idempotency.
- For support chat, retain production-only gating and never expose the secure
  mode key. For mailers, follow `docs/email_deliverability_checklist.md`.
- Do not add or upgrade gems, Node packages, payment providers, job backends,
  frontend runtimes, or template systems unless the task requires it and the
  compatibility, rollout, and rollback impact is reviewed.

## Frontend And Template Rules

- Use `.agents/skills/mosaic-html-rails` for authenticated Mosaic work. Start
  from the closest local `mosaic-html/*.html` page or comment-bounded section,
  then adapt to ERB, partials, I18n, Rails helpers, and local assets.
- Keep landing and marketing pages on the configured `LANDING_TEMPLATE` family.
  Neon is the default; Fintech is available where explicitly selected. Do not
  mix Mosaic dashboard patterns into marketing pages without a boundary task.
- Preserve Cruip source comments, Tailwind utility stacks, DOM IDs, `data-*`,
  Stimulus/Alpine/Chart/Flatpickr hooks, canvas IDs, and asset namespaces unless
  every dependent call site is updated.
- Never edit vendor sources under `app/assets/templates/...`, `mosaic-html/`,
  `neon-html/`, `fintech-html/`, or `cruip-docs-html/` for an app-specific fix.
  Put app-owned dashboard CSS in `app/assets/stylesheets/dashboard.css` or the
  established Rails-owned path.
- Preserve Propshaft, importmap, Stimulus, and Tailwind v4 conventions. Run
  `npm run build:css` when templates or CSS change Tailwind extraction/builds.
- Avoid inline `<style>` and `<script>` in views. Extract app-owned behavior to
  the existing Rails asset paths.
- Do not introduce React, Vue, shadcn/ui, Radix, Vite, Webpacker, or another
  runtime unless explicitly planned.
- Browser-facing work must cover keyboard/focus behavior, accessible labels,
  mobile layout, EN/ES length, loading/empty/error/success states, validation,
  double actions where relevant, and console/network failures.

## Verification And Review Gate

- Run the narrowest meaningful checks first, fix deterministic failures caused
  by the change, and re-run the exact failed command before expanding scope.
- Documentation-only changes: review the diff, run `git diff --check`, validate
  referenced files/skill metadata, and skip Rails/browser suites unless snippets
  or executable behavior changed.
- Focused Rails changes: run directly affected RSpec files. Broader changes:
  run the relevant non-system RSpec directories or full suite when practical.
- Constants, routes, config, or autoloading: run `bin/rails zeitwerk:check` and
  focused boot/route checks.
- Lint/security-sensitive work: run configured commands such as `bin/rubocop`,
  `bin/brakeman --no-pager`, dependency audit, or importmap audit as relevant.
- Browser-visible changes require the Browser QA Gate. Start with project-native
  deterministic checks, then a focused one-browser smoke/E2E run; use targeted
  screenshots, traces, or interactive debugging only when needed. Report
  `Browser QA: PASS`, `FAIL`, `Not applicable`, or `Not run` with the reason.
- Security-sensitive work must explicitly review authorization, ownership,
  admin boundaries, secret/log safety, webhook authenticity, payout state,
  billing idempotency, and licensing/entitlement scope.
- Before finalizing non-trivial work, apply the Rails Review Gate: code quality,
  behavior/goal alignment, tests context, database/data safety,
  security/privacy, frontend contracts, Browser QA, and residual risk. Fix clear
  failures and re-run the gate.
- Before committing or handing off, review `git status --short`, the scoped
  diff, generated/dependency files, skipped checks, and unrelated user changes.

## Project Documentation

- `README.md`: stack, setup, support chat, production QA, releases, deployment.
- `docs/database_model_reference.md`: persisted models, services, API contracts,
  and data-flow highlights.
- `docs/email_deliverability_checklist.md`: branded mailer rollout and inbox
  deliverability.
- `docs/plans/`: active durable plans only; archive completed plans under
  `docs/plans/_archive/` or delete them after preserving the useful summary.
- `.agents/skills/mosaic-html-rails/SKILL.md`: local Mosaic dashboard/account/
  auth porting workflow and template boundary rules.
