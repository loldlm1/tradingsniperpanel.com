# Plan: Self-updating deploy scripts

## Goal
Allow deploy scripts run from outside the repo to automatically switch to the latest script in the cloned repo (after `git pull`), so manual copy/paste of updated scripts is no longer needed and `.tool-versions` stays current.

## Definition of Done
- When `setup_staging.sh` or `setup_production.sh` runs from outside the repo, it re-execs the repo version after `ensure_repo`.
- Re-exec behavior is idempotent and guarded (no infinite loop), with an opt-out flag.
- README includes the preferred run flow (bootstrap/outside run and then rerun via repo script, or always run the external script which will auto-switch).

## Constraints
- Keep scripts safe for re-runs (`set -euo pipefail`), no destructive changes.
- Preserve existing root/sudo behavior and `SUDO_USER` usage.
- Keep logs concise; no long output.

## Steps
1) Add a `reexec_from_repo_if_needed` helper in `script/setup_common.sh`.
2) Wire staging/production scripts to call the helper after `ensure_repo`.
3) Add a guard env var (e.g., `SETUP_REEXEC=1`) and optional skip (e.g., `SKIP_REEXEC=1`).
4) Update README with the new behavior and recommended run commands.

## Open Questions
- None (requirements confirmed).

## Progress
- Decision: Re-exec only when the local deploy scripts differ from the repo versions; skip via `SKIP_REEXEC=1`.
- Decision: Always run external scripts; warn if someone runs from the repo path.
- Decision: Sync `setup_production.sh`, `setup_staging.sh`, and `setup_common.sh` from the repo into the local script directory.
- Commands (PASS): `rg -n \"setup_staging|setup_production\" README.md`, `sed -n '1,80p' README.md`, `apply_patch` (setup_common/setup_production/setup_staging/README).
