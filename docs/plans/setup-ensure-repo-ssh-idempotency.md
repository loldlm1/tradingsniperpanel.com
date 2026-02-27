# Setup Ensure Repo SSH Idempotency

## Goal
Make deploy reruns resilient when SSH agent has no loaded keys, while preserving non-interactive and secure git authentication behavior.

## Definition of Done
- `ensure_repo` no longer hard-fails solely because `ssh-add -L` is empty.
- SSH-based git operations remain non-interactive (`BatchMode=yes`, `GIT_TERMINAL_PROMPT=0`).
- On real git auth failure, script exits with a clear actionable error.
- Existing repo safety checks (origin mismatch, dirty tree, branch existence) remain unchanged.
- `script/setup_common.sh` passes shell syntax check.

## Constraints
- Keep change scoped to deploy script auth/idempotency behavior.
- Do not weaken security posture (no interactive prompts, no insecure SSH options).
- Preserve current repo URL behavior (SSH or HTTPS via `REPO_URL`).

## Steps
1. Update `ensure_repo` SSH handling to warn instead of failing on empty agent.
2. Wrap SSH clone/fetch/ls-remote steps with explicit auth-aware error messages.
3. Run bash syntax validation for modified script.
4. Record decisions and command outcomes (PASS/FAIL).

## Open Questions
- None.

## Execution Log
- Decision: Keep SSH non-interactive by retaining `BatchMode=yes` and `GIT_TERMINAL_PROMPT=0`.
- Decision: Remove hard dependency on loaded SSH agent keys; rely on real git command success/failure instead.
- Decision: Preserve existing repo safety checks (origin match, clean tree, branch existence) and only harden auth/idempotency behavior.
- Command: `ls -la docs/plans && rg --files docs/plans | head -n 20` -> PASS
- Command: `git status --short` -> PASS
- Command: `sed -n '1,220p' docs/plans/seed-bundle-checksum-reattach.md` -> PASS
- Command: `cat > docs/plans/setup-ensure-repo-ssh-idempotency.md <<'EOF' ... EOF` -> PASS
- Command: `sed -n '248,336p' script/setup_common.sh` -> PASS
- Command: `apply_patch (update ensure_repo in script/setup_common.sh)` -> PASS
- Command: `bash -n script/setup_common.sh` -> PASS
- Command: `bash -n script/setup_common.sh script/setup_staging.sh script/setup_production.sh` -> PASS
- Command: `git diff -- script/setup_common.sh` -> PASS
