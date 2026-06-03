This is a Rails web application.

# Trading Sniper Panel Agent Rules

Use this file for local project invariants. Keep reusable production-grade Rails
rules in the `rails-production-engineering` skill, keep Mosaic dashboard/account
porting rules in `.agents/skills/mosaic-html-rails`, and keep deeper project
architecture/security rationale in `docs/`.

## Instruction Precedence

When instructions conflict, use this order:

1. Explicit user instruction for the current task.
2. This `AGENTS.md` file.
3. Project documentation in `docs/`.
4. The `rails-production-engineering` skill and any narrower applicable skill.
5. Existing local code conventions.
6. General framework knowledge.

## Skill Stack

- Use `rails-production-engineering` as the base Rails implementation, review,
  refactor, security, migration, job, test, and deployment-readiness authority.
- Use `.agents/skills/mosaic-html-rails` for authenticated dashboard, settings,
  billing, plans, support, FAQ, and Mosaic-based auth/account frontend work.
- Use `premium-product-ui-builder` for browser-facing UX/UI work, accessibility,
  responsive behavior, theming, forms, modals, dashboard polish, and design-system
  changes.
- Use `typescript-production-engineering` for substantial JavaScript,
  TypeScript, Stimulus, frontend asset, browser protocol, or behavior-preserving
  browser-code refactors.
- Use `token-efficient-web-qa` for browser QA, Playwright smoke tests,
  screenshots, browser-console/network checks, and compact UI regression triage.
- Use `unix-macos-engineer` for shell scripts, deployment scripts, process
  management, systemd, nginx, Unix tooling, or server troubleshooting.
- Use `mermaid-diagrams` when creating or updating architecture, data-flow,
  sequence, ERD, or workflow diagrams.
- Use `find-skills` when the task asks for capabilities that may exist as an
  installable skill.

If multiple skills apply, use the smallest set that covers the task and follow
local repository conventions over reusable defaults.

Before planning or editing, identify applicable skills, open the relevant
`SKILL.md`, and keep any skill-specific file/tool usage minimal and on-scope.

## Research And MCP Usage

Use MCPs only when local repo files, this `AGENTS.md`, project docs, and
applicable skills are insufficient for the task. Prefer the smallest useful
lookup and stop researching once the implementation decision is clear.

MCP usage order:

1. Local first: inspect existing code, tests, lockfiles, config, `docs/`, and
   nearby conventions before using networked MCPs.
2. `context7`: use for version-specific library/framework/API documentation,
   especially Rails, Active Record, Hotwire, Stimulus, importmap, Propshaft,
   Tailwind, Pay, Stripe, Devise, ActiveAdmin, Pagy, Sidekiq, and JavaScript or
   TypeScript APIs. Query the exact package or framework and ask only for the
   topic needed for the current change.
3. `tavily`: use for current or broader web research that local files and
   `context7` cannot answer, such as vendor changes, security advisories,
   compatibility notes, or comparing official integration options. Prefer
   official sources and recent primary documentation over blog posts.
4. `fetch`: use only when a specific URL is already known or a search result
   needs exact page details. Do not use it as a general search tool.
5. Postgres MCP, when available: use only for targeted database inspection that
   cannot be answered from schema, seeds, factories, or docs. Never inspect or
   expose private customer data unless the user explicitly requests it and it is
   necessary for the task.
6. Playwright MCP, when available: use for browser-facing QA after native checks
   or when the task requires screenshot/console/network inspection.
7. Stop early: after enough evidence exists to make or reject the change,
   proceed with the narrowest implementation and verification.

Token-budget rules for MCPs:

- Start with one focused query; add more only when the first result is
  insufficient or conflicting.
- Prefer package/version-aware documentation over generic examples.
- Capture only the useful facts: API names, required options, constraints,
  source URL, and short rationale. Do not paste long external excerpts into
  notes, commits, or handoffs.
- Reuse context gathered earlier in the same task instead of repeating identical
  lookups.
- If external docs conflict with local lockfiles, code, or project docs, trust
  the local project state unless the task is explicitly to upgrade or migrate.
- Avoid MCP research for purely local refactors, formatting, naming, tests that
  follow existing patterns, or project rules already covered in this file.
- For security-sensitive work involving auth, admin boundaries, license keys,
  billing, webhooks, OAuth, support widgets, external HTTP, background jobs, or
  logging, verify the relevant local rules and use official external docs when
  framework or provider behavior is uncertain.
- Never send secrets, raw tokens, credentials, private customer data, raw
  license keys, authorization headers, webhook payload secrets, or `.env` values
  to MCP tools.
- Do not fetch private, localhost, internal-network, cloud-metadata, admin,
  signed, or credential-bearing URLs unless the user explicitly requests it and
  the task cannot be completed safely another way.
- In final handoffs, mention external MCP sources only when they materially
  changed the implementation decision.

## Planning And Audit Discipline

For non-trivial changes, create or update `docs/plans/<slug>.md` before coding.
Keep plans short: Goal, Definition of Done, Constraints, Steps, Open Questions,
Decisions, and Commands. Update commands with PASS/FAIL only, not long logs.

Default execution flow for non-trivial work:

1. Plan.
2. Resolve open questions or state explicit assumptions when the safe path is
   clear.
3. Mark the plan ready.
4. Implement the task.
5. Run the Audit Gate.
6. Provide a concise feature-done summary.

Audit Gate is required before finalizing non-trivial work:

- Check code pattern and efficiency.
- Check feature behavior and goal alignment.
- Check tests context: coverage, relevance, and gaps for the change.
- Use the most relevant available skill. For Rails work, use
  `rails-production-engineering` and its Review Gate.
- If FAIL is clear, fix and re-audit.
- If FAIL is ambiguous, create a mini-plan with at most 3 steps, ask the user,
  then continue and re-audit.

Keep `docs/plans/` for active work only. Once a feature is verified and merged,
move its plan to `docs/plans/_archive/<YYYY-MM-DD>-<slug>.md` or delete it after
copying a 5-10 line Post-Implementation Summary into the PR description.

## Planner Execution Discipline

When executing a plan created by `$planner` or any equivalent sprint-based plan,
treat the plan as the execution contract, not as background context.

Default execution policy:

- Execute Sprints strictly in the order written.
- Use contiguous Sprint batches only; never skip ahead.
- Low complexity: may execute the full plan only when it has 1-2 Sprints and no
  high-risk areas.
- Medium complexity: execute at most 50% of total Sprints per batch.
- High complexity: execute at most 33% of total Sprints per batch, usually with
  a practical cap of 3 Sprints per batch.
- Critical or security-sensitive plans: execute one Sprint per batch.
- Complete validation before moving forward. Create commits only when the user
  asks for commits or the plan explicitly requires them.
- Stop after each batch and provide a handoff unless the user explicitly asked
  to execute the full plan.

Reduce batch size when work touches migrations, auth, admin access, license
keys, billing, Stripe/Pay, partner payouts, referral attribution, OAuth, browser
security, external integrations, background jobs, public APIs, data contracts,
or large refactors.

If the plan becomes stale, unsafe, ambiguous, or incomplete during
implementation, stop and update or request revision of the plan before
continuing.

For `$planner`-driven phased work, compact window context only when the current
sprint/phase task is finalized and the next one is starting, only if usage is
over 50%, and carry forward a safe summary so the next sprint/phase starts with
enough context.

## Project Identity

- App name: Trading Sniper Panel.
- Rails namespace: `TradingsniperpanelCom`.
- Product: SaaS app that markets and manages MQL5 Expert Advisors, tools,
  indicators, scripts, courses, marketplace assets, subscriptions, licensing,
  partner referrals, and partner payouts.
- Primary public site: localized marketing, auth, legal, pricing, and checkout
  flows for `tradingsniperpanel.com`.
- Authenticated surface: Cruip Mosaic dashboard for licenses, analytics,
  marketplace, courses, billing, plans, support, settings, and partner areas.
- Admin surface: ActiveAdmin for catalog, billing, partner, release, and content
  management.
- API style: REST JSON v1 for license verification, heartbeats, and broker
  daily-result ingestion.
- Database: PostgreSQL.
- Background jobs: Active Job is currently configured with Sidekiq. The Solid
  Queue gem is present, and Solid Cache/Solid Cable are available, but do not
  switch queue backends without an explicit plan.
- Payments: Pay gem with Stripe as the default processor.
- Authentication: Devise, Google OAuth, roles on `User`, and ActiveAdmin admin
  boundaries.
- Localization: English and Spanish with route locale, session/user preference,
  IP/Accept-Language detection, and `I18n.fallbacks = [:en]`.
- Assets: Propshaft, importmap, Stimulus, Tailwind via `tailwindcss-rails` and
  Node CLI, Cruip template assets under `app/assets/templates/...`.

## Non-Negotiable Rules

- Keep licensing and entitlement checks server-authoritative. Do not trust
  browser params, EA client params, or admin form state for ownership, active
  subscription, add-on access, trial access, or marketplace access.
- Preserve public API contracts for `/api/v1/licenses/verify`,
  `/api/v1/licenses/heartbeat`, and `/api/v1/broker_accounts/daily_results`
  unless the task explicitly plans a versioned contract change.
- Preserve API error codes and response shapes documented in
  `docs/database_model_reference.md` unless a planned API change updates docs
  and tests together.
- Never expose license keys, `encrypted_key` values, Stripe secrets, webhook
  secrets, OAuth secrets, Tawk.to secure-mode keys, MaxMind license data,
  session tokens, raw credentials, or private customer/billing data in rendered
  HTML, JavaScript payloads, data attributes, URLs, logs, errors, telemetry, or
  MCP requests.
- Use integer cents and decimal-safe calculations for money. Never use floats
  for money or exact decimal values.
- Keep Stripe calls idempotent, store processor/client references when
  available, and let Pay webhooks sync processor state.
- Never rescue-and-forget Stripe, Pay, OAuth, email, GeoIP, or licensing errors.
  Log structured context and re-raise or handle narrowly.
- Preserve referral attribution: set referral cookies on marketing entry points,
  call referral linking after sign-up, generate referral codes, and respect
  locale in shareable/referral links.
- Avoid duplicate commissions, duplicate payouts, duplicate license grants, and
  double access when manual billing, one-time purchases, subscriptions, refunds,
  or partner payout states change.
- Keep external API calls, Stripe sync, GeoIP lookups, email delivery, release
  notifications, and bulk work out of request hot paths unless intentionally
  synchronous and covered by tests.
- Do not edit vendor template assets under `app/assets/templates/...`,
  `mosaic-html/`, `neon-html/`, `fintech-html/`, or `cruip-docs-html/` to make
  a single app change easier.
- Do not add or upgrade gems, Node packages, payment providers, frontend
  runtimes, background job backends, or template systems unless the task clearly
  needs it and the compatibility impact is reviewed.

## Domain Boundaries

Core areas in this app:

- `Accounts/Auth`: Devise users, OAuth callbacks, terms acceptance, roles,
  locale preference, and admin access.
- `Catalog`: ExpertAdvisors, bundles, add-ons, courses, lessons, marketplace
  assets, tags, release snapshots, and product release notifications.
- `Licensing`: licenses, license verification, heartbeats, online sessions,
  broker accounts, lane magic numbers, and daily broker results.
- `Billing`: billing plans, plan entitlements, Pay customers/subscriptions/
  charges/webhooks, Stripe Checkout, billing portal, manual transactions, and
  manual subscriptions.
- `Referrals/Partners`: refer gem records, partner profiles, memberships,
  commissions, payout requests, discount resolution, and payout notifications.
- `Dashboard`: authenticated user workflows for analytics, downloads, courses,
  marketplace access, billing, support, settings, product releases, and partner
  state.
- `Admin`: ActiveAdmin workflows for operational catalog, billing, partner,
  release, and content management.
- `Localization/Branding`: EN/ES routes and copy, `LANDING_TEMPLATE`, support
  chat config, SEO/sitemap/robots, and branded mailers.

Use `docs/database_model_reference.md` as the high-signal map for persisted
models, common services, API payloads, and data-flow highlights.

## Implementation Rules

- Put business rules in models, domain modules, services, policies, commands,
  or query objects as the local architecture expects. Keep controllers thin:
  authentication/authorization, parameter normalization, orchestration, and
  response shape.
- Enforce ownership, role, entitlement, and admin boundaries inside the
  domain/query layer where practical, not only in controllers or views.
- Prefer explicit scopes and current-user/current-role inputs over raw IDs from
  params for sensitive operations.
- Use strong params, model validations, database constraints, unique indexes,
  transactions, idempotent jobs, and retry-safe service objects for data
  integrity.
- Review migrations for production data, locks, defaults, indexes, extension
  usage, backfills, reversibility, and rollback behavior before running or
  handing off.
- Keep Active Storage attachments behind authorization checks and entitlement
  checks. Do not expose direct download paths for gated EA bundles, marketplace
  files, or course assets without checking access.
- Use Active Job for durable work that touches Stripe/Pay sync, GeoIP, email,
  product releases, partner payout notifications, licensing maintenance, or
  bulk/admin operations. Jobs must be retry-safe and idempotent.
- Keep API controllers JSON-only where expected. Validate required payload
  shapes before invoking domain services and keep documented error codes stable.
- Use Pagy or another existing project pagination pattern for user-facing lists
  that can grow.
- Eager load associations for dashboard/admin hot paths that render collections
  or aggregate billing/partner/license state.
- Drive durable UI copy through `I18n` in EN/ES. Never concatenate translated
  strings; use interpolation and fallbacks.
- Keep helpers pure and presentation-focused.
- Avoid concerns when explicit composition or a small service object is clearer.
- Avoid inline `<style>` and `<script>` in views. Extract app-owned CSS/JS to
  the existing Rails asset paths and include it with the appropriate tags.

## Rails, Admin, And API Rules

- Use Rails 8 conventions from `rails-production-engineering` for framework
  details.
- Prefer local binstubs and repo scripts: `bin/rails`, `bundle exec rspec`,
  `bin/rubocop`, `bin/brakeman`, `npm run build:css`, and documented scripts.
- Use RSpec for tests. Prefer request specs for auth, referrals, billing
  webhooks, dashboard/API flows, admin boundaries, and localization; model specs
  for validations/calculations; service specs for business rules; mailer specs
  for branded email behavior.
- Stub external HTTP/Stripe/OAuth/provider calls. Do not hit live providers in
  tests.
- Use factories with lean traits. Avoid brittle copy assertions; prefer I18n
  keys or stable semantic assertions where practical.
- For ActiveAdmin changes, preserve authorization boundaries, ransack
  allowlists, permitted params, safe scopes, and operational auditability.
- For Pay/Stripe changes, use `pay_customer default_payment_processor: :stripe`
  on billable models, keep checkout/session creation idempotent, and let Pay
  webhook models reflect processor state.
- For referral/partner changes, preserve refer gem callbacks, partner membership
  depth logic, payout state transitions, and commission idempotency.
- For support chat changes, keep production-only gating and never expose the
  Tawk.to secure-mode API key.
- For email changes, use `docs/email_deliverability_checklist.md` for rollout
  and deliverability checks.

## Frontend And UI Rules

- Use `.agents/skills/mosaic-html-rails` for authenticated dashboard, settings,
  billing, plans, support, FAQ, and Mosaic auth/account pages. Start from the
  closest local `mosaic-html/*.html` source page or comment-bounded section,
  then adapt to ERB, partials, I18n, Rails asset paths, and helpers.
- Keep landing and marketing pages on the configured `LANDING_TEMPLATE`
  boundary. Neon is the default; Fintech is available where the app explicitly
  selects it. Do not mix Mosaic dashboard patterns into marketing pages unless
  the task explicitly concerns that boundary.
- Preserve Cruip source section comments, Tailwind utility stacks, DOM IDs,
  `data-*` hooks, Stimulus identifiers, Alpine/Chart/Flatpickr hooks, canvas
  IDs, and asset namespaces unless the task updates every dependent call site.
- Do not edit vendor template CSS/JS. Put app-owned dashboard CSS in
  `app/assets/stylesheets/dashboard.css` or the established Rails-owned asset
  path.
- Preserve Propshaft/importmap/Stimulus/Tailwind conventions unless a plan
  explicitly changes the asset pipeline.
- Preserve Tailwind v4 and `tailwindcss-rails` build conventions. Use
  `npm run build:css` when CSS or template class extraction changes need
  verification.
- Use `premium-product-ui-builder` for user-visible UI quality: accessibility,
  responsive behavior, empty/loading/error/success states, forms, modals,
  dashboard density, visual polish, and EN/ES copy length.
- Use `typescript-production-engineering` for substantial browser-code work in
  Stimulus controllers, importmap modules, frontend assets, or JS-to-TS
  refactors.
- Do not introduce React, Vue, shadcn/ui, Radix, Vite, Webpacker, or a new
  frontend runtime unless explicitly planned.
- Browser-facing changes must account for mobile, long localized text, keyboard
  navigation, focus states, validation states, and console/network errors.

## Verification

- Use the narrowest meaningful checks while developing.
- Documentation-only changes: review the diff and run no Rails test suite unless
  the docs change includes executable snippets or task-specific commands.
- Focused Rails code changes: run the relevant `bundle exec rspec path/to/spec.rb`
  files and any directly affected request/service/model specs.
- Broader Rails changes: run `bundle exec rspec` or the repo's documented
  equivalent when practical.
- Autoloading/routing/config changes: run `bin/rails zeitwerk:check` and a
  focused boot or request check when practical.
- Lint/security-sensitive changes: run `bin/rubocop` and/or `bin/brakeman` when
  available and relevant.
- CSS/template extraction changes: run `npm run build:css` when class extraction
  or generated CSS can be affected.
- Browser-facing changes to views, layouts, helpers, navigation, forms,
  Stimulus, CSS, dashboard, admin, checkout, support, or auth flows require a
  Browser QA Gate. Use `token-efficient-web-qa` or project-native browser tests
  after native checks.
- Security-sensitive changes require tests or focused review for authorization,
  admin boundaries, token secrecy, log safety, webhook authenticity, payout
  state, and license/entitlement ownership.
- If a command cannot run, report the exact limitation, command, and residual
  risk.
- Before final handoff, review the diff and call out changed files,
  verification, skipped checks, browser QA status, and remaining risks.

## Project Documentation

- `README.md`: stack, local setup, support chat setup, production QA, product
  release flow, and server/deploy notes.
- `docs/database_model_reference.md`: persisted model map, common services, API
  surface, and data-flow highlights.
- `docs/email_deliverability_checklist.md`: branded mailer rollout and inbox
  deliverability checklist.
- `docs/plans/`: active implementation plans only; archive completed plans under
  `docs/plans/_archive/` when appropriate.
- `.agents/skills/mosaic-html-rails/SKILL.md`: local Mosaic dashboard/account/
  auth porting workflow and template boundary rules.
