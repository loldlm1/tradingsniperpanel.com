# Update AGENTS Instructions

Status: Complete

## Goal

Update this Rails project's `AGENTS.md` to follow the newer structure used by `/home/loldlm/elixir_projects/chatbot_hub_ve/AGENTS.md`, adapted to this app's Rails stack and local project rules.

## Definition of Done

- `AGENTS.md` uses the newer instruction layout: precedence, MCP research discipline, planner execution discipline, project identity, non-negotiable rules, implementation/frontend rules, verification, and docs map.
- Rails-specific guidance names `rails-production-engineering` as the base Rails skill and preserves the current project-specific rules for Mosaic, I18n, Pay/Stripe, referrals, Sidekiq/Solid Queue, assets, and tests.
- The update avoids obsolete skill names where possible and reflects the available project/local skill stack.
- Audit Gate is run before final handoff.

## Constraints

- Keep reusable framework guidance in skills; keep only project invariants in `AGENTS.md`.
- Do not change application code.
- Keep MCP/web research rules local-first and token-efficient.
- Keep `docs/plans/` lightweight and active only while this task is in progress.

## Steps

1. Compare current Rails `AGENTS.md` with ChatbotHubVe `AGENTS.md`.
2. Inspect local Rails stack, routes, docs, and project skills.
3. Rewrite `AGENTS.md` with the newer structure adapted to this repo.
4. Review the diff and run a documentation-focused Audit Gate.

## Open Questions

- None. Treat ChatbotHubVe's structure as the template and adapt content to this Rails app.

## Decisions

- Use `rails-production-engineering` as the Rails implementation authority for this repo.
- Keep `.agents/skills/mosaic-html-rails` as the project-specific Mosaic dashboard/account/auth frontend skill.
- Preserve existing Pay/Stripe, referrals, I18n, asset, and testing rules as project invariants.
- Document Sidekiq as the current Active Job backend while noting that Solid Queue is present but not the configured queue adapter.

## Commands

- `git status --short`: PASS
- `git branch --show-current`: PASS
- `sed -n '1,260p' AGENTS.md`: PASS
- `sed -n '1,320p' /home/loldlm/elixir_projects/chatbot_hub_ve/AGENTS.md`: PASS
- `find docs -maxdepth 2 -type f | sort`: PASS
- `sed -n '1,220p' Gemfile`: PASS
- `sed -n '1,220p' config/application.rb`: PASS
- `sed -n '1,220p' config/routes.rb`: PASS
- `find .agents -maxdepth 3 -type f | sort`: PASS
- `sed -n '1,220p' README.md`: PASS
- `sed -n '1,260p' docs/database_model_reference.md`: PASS
- `sed -n '1,220p' docs/email_deliverability_checklist.md`: PASS
- `sed -n '1,220p' package.json`: PASS
- `sed -n '1,220p' .agents/skills/mosaic-html-rails/SKILL.md`: PASS
- `find spec -maxdepth 2 -type f | sort | sed -n '1,120p'`: PASS
- `git diff -- AGENTS.md docs/plans/update-agents-instructions.md`: PASS
- `git diff --check -- AGENTS.md docs/plans/update-agents-instructions.md`: PASS
- Rails/RSpec suite: PASS not applicable for documentation-only instruction update

## Audit Gate

- Code pattern and efficiency: PASS. `AGENTS.md` now keeps reusable Rails rules in `rails-production-engineering` and local invariants in the repo file.
- Feature behavior and goal alignment: PASS. The file follows the ChatbotHubVe-style structure and adds the requested Rails skill stack.
- Tests context: PASS. Documentation-only change; whitespace check and diff review completed. No app tests required.
- Database and data safety: PASS. No application code, migrations, schema, or data operations changed.
- Security and privacy: PASS. The new rules strengthen secret, token, billing, webhook, OAuth, and MCP privacy handling.
- Frontend and browser contracts: PASS. No UI code changed; the new rules preserve Mosaic, template, Stimulus, Tailwind, and browser QA boundaries.
- Browser QA: PASS not applicable for documentation-only change.
