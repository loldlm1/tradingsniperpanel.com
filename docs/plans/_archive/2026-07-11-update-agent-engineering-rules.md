# Update Agent Engineering Rules

Status: Complete

## Goal

Align the repository's agent instructions and local Mosaic skill with the
current `/home/loldlm/.codex/skills` stack while preserving Trading Sniper
Panel's project-specific product, security, UI, and release invariants.

## Definition of Done

- `AGENTS.md` routes work only to currently installed, applicable skills.
- Planning, review, commit, research, and verification rules match the current
  Rails, planner, token-saver, and browser-QA skill contracts.
- The repository-owned Mosaic skill and its metadata remain concise, valid,
  and consistent with the project Browser QA Gate.
- Documentation references and skill metadata validate without errors.
- Only the requested documentation changes are committed; the pre-existing
  untracked `docs_eas.zip` remains untouched.

## Constraints

- Do not change application code, dependencies, generated assets, or vendor
  templates.
- Keep reusable framework guidance in installed skills and retain only
  project-specific invariants in repository instructions.
- Preserve public API, billing, licensing, referral, localization, Mosaic, and
  deployment boundaries.
- Use documentation-only validation plus the Rails Review Gate; browser QA is
  not applicable.

## Steps

1. Inventory repository instruction files, current project stack, and installed
   Codex skill metadata.
2. Update `AGENTS.md` skill routing and agent workflow rules, removing stale or
   duplicated reusable guidance.
3. Update the local Mosaic skill, references, and UI metadata to require the
   current native-first Browser QA Gate.
4. Validate Markdown/YAML structure, skill metadata, internal references, and
   the final diff.
5. Archive this plan with a post-implementation summary and commit the scoped
   changes.

## Open Questions

- None. Use the installed skill directories as the source of truth and retain
  stricter repository-specific product rules where they remain applicable.

## Decisions

- Keep `rails-production-engineering` as the base skill.
- Route database, deployment, MQL5, UI, browser QA, TypeScript/JavaScript, AI
  agent app, and token-efficiency work to their current installed skills.
- Treat `create-plan` as chat-only planning and `$planner` as explicit saved,
  sprint-based planning; do not require saved plans for every implementation.
- Replace the older Audit Gate wording with the current Rails Review Gate.
- Make deterministic browser QA required for browser-visible Mosaic changes,
  with interactive tooling reserved for targeted fallback.

## Commands

- `rtk git status --short`: PASS (pre-existing `docs_eas.zip` only)
- Skill and instruction inventory: PASS
- Project stack inspection: PASS
- `quick_validate.py .agents/skills/mosaic-html-rails`: PASS
- `ruby` YAML parse for `agents/openai.yaml`: PASS
- Markdown fence/trailing-whitespace validation: PASS
- Installed skill routing check: PASS
- Stale skill/browser-QA wording search: PASS
- `git diff --check`: PASS
- Final scoped diff review: PASS
- Rails/RSpec suite: Not applicable (documentation and skill guidance only)
- Browser QA: Not applicable (no browser-visible implementation changed)
- Commit: Pending at archival; completed in the task handoff

## Review Gate

- Code quality and maintainability: PASS. Reusable guidance is routed to the
  installed skills and the root file is shorter and more project-specific.
- Feature behavior and goal alignment: PASS. Skill routing, planning, review,
  API-contract, and Browser QA rules match the current stack.
- Tests context: PASS. Structural, metadata, reference, and whitespace checks
  cover this documentation-only change; application specs are not applicable.
- Database and data safety: PASS. No schema, migration, SQL, or data changed.
- Security and privacy: PASS. Secret, customer-data, licensing, billing, MCP,
  and local-browser boundaries remain explicit.
- Frontend and browser contracts: PASS. Mosaic hooks/template boundaries are
  preserved and the QA workflow is strengthened without changing UI code.
- Browser QA: Not applicable.
- Residual risks: Installed skill names may change later; the routing check
  should be repeated during the next agent-rule refresh.

## Post-Implementation Summary

- Replaced obsolete skill routes with the current Rails, PostgreSQL, DevOps,
  MQL5, UI, TypeScript, browser QA, AI-agent, planner, and token-saver stack.
- Updated normal planning and explicit `$planner` execution/commit boundaries.
- Replaced the older Audit Gate model with the Rails Review Gate.
- Added the missing `/api/v1/licenses/instance_magic` public contract.
- Preserved project-specific licensing, billing, referral, localization,
  template, job, and data-safety invariants.
- Updated the local Mosaic skill and metadata to require native-first,
  deterministic Browser QA for browser-visible changes.
