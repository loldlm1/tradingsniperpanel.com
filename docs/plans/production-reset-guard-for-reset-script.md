# Plan: Production Reset Guard for DB Reset Script

## Goal
Extend `script/reset_staging_db.sh` so it can target staging or production, while adding a clear and explicit confirmation gate before any production database reset.

## Definition of Done
- Script supports selecting target environment (`staging` default, `production` optional).
- Existing staging behavior remains backward compatible.
- Production `reset` requires explicit operator confirmation and fails closed if not provided.
- Production and staging runs use the correct app paths, env files, DB env keys, and systemd services.
- Script help text documents the new argument(s) and confirmation flow.
- Script passes shell syntax validation.

## Constraints
- Keep implementation in Bash and consistent with existing deploy script style.
- Avoid changing unrelated setup scripts.
- Preserve safe defaults (staging + no destructive production action without confirmation).

## Steps
1. Add argument parsing for action + target + production confirmation flag.
2. Centralize environment-specific mapping (app dir, env file, DB keys, services, labels).
3. Add production-reset confirmation guard with clear warning output and typed token check.
4. Reuse existing reset/migrate/seed execution flow with environment-specific values.
5. Update usage/help output with examples and safety notes.
6. Run syntax checks and smoke-check the help command.

## Open Questions
- None.

## Decisions
- Keep default target as staging for backwards compatibility.
- Require both an explicit flag (`--confirm-production-reset`) and a typed token for production `reset`.
- Parse `--help` before root checks so usage can be inspected without `sudo`.

## Commands (PASS/FAIL)
- PASS: `sed -n '1,220p' /home/loldlm/.agents/skills/unix-macos-engineer/SKILL.md`
- PASS: `sed -n '1,260p' script/reset_staging_db.sh`
- PASS: `rg -n "DB_NAME_(STAGING|PRODUCTION)|tradingsniperpanel.*service|staging\.env|production\.env" -S .`
- PASS: `apply_patch docs/plans/production-reset-guard-for-reset-script.md`
- PASS: `apply_patch script/reset_staging_db.sh`
- PASS: `bash -n script/reset_staging_db.sh`
- PASS: `bash script/reset_staging_db.sh --help`
- FAIL: `command -v shellcheck` (not installed in this environment)
