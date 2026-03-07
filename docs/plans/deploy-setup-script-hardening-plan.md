# Plan: Deploy Setup Script Hardening

**Generated**: 2026-03-07
**Estimated Complexity**: High

## Goal
Make the deploy/setup shell scripts reliable and repeatable on Ubuntu 22.04, with special focus on the current failures around GitHub access, external script self-update/re-exec, and idempotent reruns for staging and production.

## Decisions Locked In
- Git access remains SSH-first and SSH-only by default; HTTPS is not a first-class automatic fallback for this effort.
- On the current VPS/network path, GitHub SSH should default to `ssh.github.com:443`; port 22 is not the preferred path for this environment.
- The scripts should support being run from arbitrary external paths, not only `/home/admin/deploy_scripts`.
- Scope is phase-based: harden `script/setup_common.sh`, `script/setup_production.sh`, and `script/setup_staging.sh` first; only touch other `script/` files if shared-helper fallout requires it.
- Validation is manual smoke testing on your VPS first; you will bring back logs before any broader expansion.
- Firewall/network assumptions must reflect the current GCore-managed firewall, not `ufw`.
- Manual smoke validation is sufficient for this phase; `shellcheck` is optional and not required for Definition of Done.
- The deploy/app user is the non-root sudo caller (`SUDO_USER`), such as `admin`; direct root-only execution should remain unsupported or fail clearly.
- If GitHub repo access is unavailable, the setup scripts should fail immediately before any provisioning work begins.

## Overview
The current deploy flow depends on external copies of `setup_production.sh`, `setup_staging.sh`, and `setup_common.sh` that bootstrap the app repo, self-update from the repo, and then continue provisioning. Two concrete breakpoints were observed:

- `ensure_repo` still fails hard when GitHub SSH over port 22 is unavailable or when the active external script copy is stale and cannot fetch its own fix path.
- `reexec_from_repo_if_needed` assumes the updated external script path is directly executable, which breaks on at least one real deployment path with `env: ... Permission denied`.

The implementation plan should harden the shared shell helpers first, then verify downstream scripts that depend on them (`setup_*`, `reset_staging_db.sh`, `clear_sidekiq_staging.sh`, and any other consumers in `script/`).

## Definition of Done
- `sudo bash <external-path>/setup_production.sh` and `sudo bash <external-path>/setup_staging.sh` can be rerun safely on the same host without failing on stale-script re-exec, missing execute bits, or GitHub SSH port changes.
- Git access is handled through an explicit, documented fallback order with actionable diagnostics for:
  - SSH agent socket available
  - direct `~/.ssh` key available
  - GitHub SSH over `ssh.github.com:443` as the default path for this infrastructure
  - optional explicit override to port 22 only if the operator forces it and the network path supports it
- Preflight checks fail before mutating the host when repo access or script execution prerequisites are missing.
- Shared helper changes do not regress `script/reset_staging_db.sh` or `script/clear_sidekiq_staging.sh`.
- The plan includes a validation matrix for fresh host, rerun, blocked port 22, stale external scripts, and external script directories with execution constraints.
- README/operator guidance reflects the supported invocation model and troubleshooting path.

## Constraints
- Target server OS is Ubuntu 22.04.
- Production and staging run on the same VPS.
- The deploy scripts are expected to be runnable from outside the repo, not only from `script/` inside a checked-out app directory.
- The current implementation relies on Bash, `sudo`, `git`, `ssh`, `asdf`, `systemd`, `nginx`, `postgresql`, and `redis`.
- Changes should stay idempotent and should not require manual cleanup between reruns.
- Scope should stay centered on shell/deploy reliability; no Rails feature changes are required.
- Network reachability to GitHub may now differ from previous weeks because firewall control moved to GCore and the server IP changed.

## Current Findings
- `script/setup_common.sh` already contains GitHub SSH 22 -> 443 fallback logic, but a stale external script copy can still fail before it can self-update.
- `reexec_from_repo_if_needed` uses `exec env SETUP_REEXECED=1 "${local_script}" ...`, which assumes the external file is directly executable from its filesystem location.
- `run_as_app_user` does not currently force `HOME` with `sudo -H`, so the execution contract for `~/.ssh`, `~/.bashrc`, and `~/.asdf` should be made explicit.
- `reset_staging_db.sh` and `clear_sidekiq_staging.sh` both depend on the same `setup_common.sh` helpers, so helper refactors will have blast radius beyond deploy.
- All current scripts pass `bash -n`, but there is no automated shell-specific validation or deploy smoke harness in the repo.
- The current network issue is likely environmental as well as code-path related, because the server IP changed and egress policy is now managed outside the host by GCore.
- VPS probe results on 2026-03-07:
  - PASS: `ssh -o HostName=ssh.github.com -p 443 -T git@github.com` works as `admin`.
  - FAIL/HANG: `ssh -T git@github.com` on port 22 did not complete promptly and was manually interrupted.
  - PASS: no dedicated `noexec` mounts were shown for `/home` or `/opt` in the sampled `mount` output.
  - FAIL: `sudo -u admin -H bash -lc ...` emitted `/home/admin/.asdf/asdf.sh: line 25: cd: /root: Permission denied`, confirming the current shell startup contract is not clean when invoked from root's working directory.

## Research Snapshot
- PASS: Read `AGENTS.md` and the `planner` / `unix-macos-engineer` skill guidance.
- PASS: Inspected `script/setup_common.sh`, `script/setup_production.sh`, `script/setup_staging.sh`, `script/reset_staging_db.sh`, `script/clear_sidekiq_staging.sh`, and `script/build_active_admin_css`.
- PASS: Confirmed current script syntax with `bash -n` on the shell scripts in `script/`.

## Prerequisites
- Access to a representative Ubuntu 22.04 host or disposable VM for validation.
- One deployment path that uses external script copies (for example `/opt/tradingsniperpanel-deploy` or `/home/admin/deploy_scripts`).
- A GitHub SSH key already present for the target app user or loaded through the caller's agent.
- Ability to collect manual smoke-test logs from the current VPS after plan execution begins.

## Sprint 1: Define The Supported Deploy Contract
**Goal**: Remove ambiguity about how external scripts are supposed to be invoked and what auth/runtime environments are officially supported.
**Demo/Validation**:
- A short contract exists for invocation, external script location, auth modes, and supported fallback behavior.
- Failure paths are classified as supported, unsupported, or explicitly operator-configurable.

### Task 1.1: Lock Invocation And External Script Assumptions
- **Location**: `script/setup_common.sh`, `README.md`, `docs/plans/deploy-setup-script-hardening-plan.md`
- **Description**: Define the supported operator entrypoints (`sudo bash <script>` vs direct execute), expected external script directories, and whether noexec-mounted paths must be supported.
- **Dependencies**: None
- **Acceptance Criteria**:
  - The plan states the canonical invocation pattern.
  - The plan states that arbitrary external paths are supported as long as the files are readable.
  - The implementation avoids depending on direct path execution for the self-update handoff.
- **Validation**:
  - Review against observed failing path `/home/admin/deploy_scripts`

### Task 1.2: Lock Git Access Fallback Policy
- **Location**: `script/setup_common.sh`, `README.md`
- **Description**: Define the exact SSH-only fallback order for repo access, using `ssh.github.com:443` as the default GitHub path for this infrastructure and keeping any port-22 use as an explicit operator override only.
- **Dependencies**: Task 1.1
- **Acceptance Criteria**:
  - One supported fallback matrix is documented.
  - Error messages map cleanly to the fallback matrix.
- **Validation**:
  - Manual reasoning against the reported staging and production failures

### Task 1.3: Define Blast Radius For The Shared Helper Refactor
- **Location**: `script/setup_common.sh`, `script/reset_staging_db.sh`, `script/clear_sidekiq_staging.sh`
- **Description**: Decide whether this effort should stop at deploy/setup or also standardize the shared helper contract for the other scripts in `script/`.
- **Dependencies**: Task 1.1
- **Acceptance Criteria**:
  - In-scope scripts are listed explicitly.
  - Non-goals are recorded if some scripts are intentionally excluded.
- **Validation**:
  - Scope review against current `script/` usage

## Sprint 2: Harden Shared Shell Helpers
**Goal**: Fix the shared execution and Git/bootstrap primitives before touching environment-specific provisioning flow.
**Demo/Validation**:
- A dry run or smoke run reaches preflight and self-update without the current SSH/re-exec breakpoints.

### Task 2.1: Make `run_as_app_user` Deterministic
- **Location**: `script/setup_common.sh`
- **Description**: Normalize `sudo` execution so the target user's `HOME`, startup working directory, shell startup, `SSH_AUTH_SOCK`, and `PATH` are explicit rather than inherited accidentally.
- **Dependencies**: Sprint 1
- **Acceptance Criteria**:
  - `~/.ssh`, `~/.bashrc`, and `~/.asdf` resolution are deterministic.
  - Helper execution does not depend on starting from a directory readable by the target user.
  - Helper behavior is documented for both agent and direct-key auth.
- **Validation**:
  - Manual command probes as the app user
  - Regression check for `reset_staging_db.sh` and `clear_sidekiq_staging.sh`

### Task 2.2: Add Repo Access Preflight Before Host Mutation
- **Location**: `script/setup_common.sh`, `script/setup_production.sh`, `script/setup_staging.sh`
- **Description**: Move repo/auth/external-script checks early enough that missing repo access, blocked GitHub ports, or unsupported execution environments fail before `apt`, service, or file mutations, and make the repo check fail-fast when GitHub is unavailable.
- **Dependencies**: Task 2.1
- **Acceptance Criteria**:
  - Repo access failures happen before package installation or service changes.
  - Diagnostics distinguish timeout, auth rejection, missing key, blocked/closed GitHub SSH ports, and unsupported invocation environment.
  - The scripts do not continue into partial setup when repo sync cannot succeed.
- **Validation**:
  - Smoke test with bad repo access
  - Smoke test with SSH 22 blocked

### Task 2.3: Replace Direct Self-Reexec With Interpreter-Driven Reexec
- **Location**: `script/setup_common.sh`
- **Description**: Rework self-update handoff so it re-runs through Bash (or another explicit interpreter contract) instead of depending on the updated file being directly executable from its path.
- **Dependencies**: Task 2.2
- **Acceptance Criteria**:
  - Self-update works when invoked as `sudo bash ...`.
  - Self-update does not depend on the external script file being executable by path alone.
  - Script permissions are still normalized when copying updated files.
- **Validation**:
  - Re-run from an external script directory after forcing a self-update
  - Verify behavior on a directory that reproduces the current `Permission denied` failure

### Task 2.4: Harden Git Bootstrap And Error Reporting
- **Location**: `script/setup_common.sh`
- **Description**: Refactor `ensure_repo` into clearer phases for clone/fetch/origin/branch validation and emit targeted remediation steps tied to the chosen fallback path.
- **Dependencies**: Task 2.2
- **Acceptance Criteria**:
  - The user can tell whether failure is GCore/network port reachability, auth, branch mismatch, origin mismatch, or dirty worktree.
  - The default GitHub path uses `ssh.github.com:443` and avoids long hangs on port 22 in this environment.
  - Stale external script copies do not mask the real remediation path.
- **Validation**:
  - Simulated fetch failure
  - Existing checkout with mismatched remote or branch

## Sprint 3: Apply The Hardened Contract To Environment Scripts
**Goal**: Make production and staging setup flows converge safely under repeated execution and shared-host deployment.
**Demo/Validation**:
- Production and staging scripts can be run twice in sequence on the same host without drift or the currently reported failures.

### Task 3.1: Re-sequence Setup Flow Around Preflight And Self-Update
- **Location**: `script/setup_production.sh`, `script/setup_staging.sh`
- **Description**: Ensure the environment scripts perform only the minimum required discovery before preflight/self-update, then continue with provisioning once the executing script copy and repo state are trustworthy.
- **Dependencies**: Sprint 2
- **Acceptance Criteria**:
  - Stateful provisioning does not begin until preflight passes.
  - Self-update occurs at a predictable point with no partial state ambiguity.
- **Validation**:
  - Fresh host smoke test
  - Rerun smoke test

### Task 3.2: Verify Shared-Helper Consumers
- **Location**: `script/reset_staging_db.sh`, `script/clear_sidekiq_staging.sh`, `script/build_active_admin_css`
- **Description**: Review and adjust downstream scripts only where shared-helper changes require it, keeping the scope narrow and avoiding unnecessary rewrites.
- **Dependencies**: Sprint 2
- **Acceptance Criteria**:
  - Helper contract changes do not break reset or Sidekiq cleanup flows.
  - Any script-specific follow-up stays limited to actual compatibility needs.
- **Validation**:
  - `bash -n` on all touched scripts
  - Targeted smoke commands for reset/cleanup where feasible

### Task 3.3: Update Operator Documentation
- **Location**: `README.md`
- **Description**: Refresh the deployment instructions so they match the hardened invocation model, fallback order, and troubleshooting path.
- **Dependencies**: Tasks 3.1 and 3.2
- **Acceptance Criteria**:
  - README reflects the actual supported flow for external deploy scripts.
  - Troubleshooting steps match the new diagnostics.
- **Validation**:
  - Read-through against the plan and the known failures

## Sprint 4: Validation Matrix And Audit Gate
**Goal**: Leave an explicit verification path and a required PASS/FAIL audit before implementation is marked done.
**Demo/Validation**:
- The final verification matrix can reproduce or rule out the reported failures.

### Task 4.1: Run Manual Validation Matrix
- **Location**: active implementation notes in `docs/plans/deploy-setup-script-hardening-plan.md`
- **Description**: Validate at least these cases: fresh external-script bootstrap, rerun on existing host, GitHub SSH 22 blocked with 443 available, no SSH agent but on-disk key present, stale external scripts needing update, and the `Permission denied` re-exec path. Collect the VPS logs first and use them to decide whether broader script hardening is needed.
- **Dependencies**: Sprint 3
- **Acceptance Criteria**:
  - Each case is marked PASS/FAIL with short notes.
  - Remaining gaps are explicit rather than implied.
- **Validation**:
  - Manual execution on a test host

### Task 4.2: Audit Gate
- **Location**: active implementation notes in `docs/plans/deploy-setup-script-hardening-plan.md`
- **Description**: Run the repo-required audit for code pattern and efficiency, feature behavior versus goal alignment, and tests/validation coverage before calling the work done.
- **Dependencies**: Task 4.1
- **Acceptance Criteria**:
  - Audit result is recorded as PASS or FAIL.
  - Any FAIL loops back into fixes and re-audit.
- **Validation**:
  - Final implementation review

## Testing Strategy
- Keep `bash -n` as a baseline syntax gate for all touched scripts.
- Use a manual smoke matrix on Ubuntu 22.04 because these scripts mutate system packages, services, and SSH/Git runtime state.
- For shared-helper changes, verify both deploy scripts plus at least one downstream consumer (`reset_staging_db.sh` or `clear_sidekiq_staging.sh`).
- Capture enough output to distinguish auth failures, port reachability failures, re-exec failures, and post-provision verification failures.
- Treat GCore-managed firewall behavior as part of the validation matrix, not as an out-of-band assumption.
- Include one smoke test from a root-owned working directory to verify the target user shell initialization no longer trips over `/root`.

## Potential Risks And Gotchas
- A stale external script copy cannot self-update through a repo fetch if the fetch path itself is what is broken; the plan may need an explicit operator recovery path for that bootstrap deadlock.
- If `/home/admin/deploy_scripts` lives on a `noexec` mount, direct execution will keep failing even with correct mode bits; the re-exec strategy must account for that possibility.
- Tightening `sudo` environment handling can expose hidden reliance on inherited variables from the caller shell.
- Moving preflight earlier improves safety but can change the current operator experience if `.envrc` creation or package installation previously happened before repo validation.
- The server IP change may have invalidated upstream allowlists or network policy outside the host, so code fixes alone may not fully resolve connectivity until the GCore rules are verified.

## Rollback Plan
- Keep shell changes concentrated in `script/setup_common.sh` and the two deploy entrypoints so rollback can revert a small file set.
- If the hardened re-exec/bootstrap path misbehaves, restore the previous external script copies manually and rerun with `SKIP_REEXEC=1` as a temporary escape hatch if that remains supported.
- If helper contract changes break downstream scripts, revert the helper changes together with any compatibility updates in `reset_staging_db.sh` and `clear_sidekiq_staging.sh`.

## Open Questions
- None pending for phase-1 implementation planning.

## Execution Notes
- PASS: Hardened `script/setup_common.sh` for deterministic app-user execution, GitHub SSH defaulting to `ssh.github.com:443`, repo access preflight, and bash-driven self-reexec.
- PASS: Reordered `script/setup_production.sh` and `script/setup_staging.sh` so repo sync happens before package installation and broader provisioning.
- PASS: Updated `README.md` to match the new deploy contract: bootstrap tools, canonical `sudo bash` usage, 443-default GitHub SSH, manual recopy guidance for stale external scripts, and non-login troubleshooting commands.
- PASS: Command `bash -n script/setup_common.sh script/setup_production.sh script/setup_staging.sh script/reset_staging_db.sh script/clear_sidekiq_staging.sh`
- PASS: Command `bash -lc 'source script/setup_common.sh; select_git_ssh_command git@github.com:loldlm1/tradingsniperpanel.com.git'`
- PASS: Command `GITHUB_SSH_PORT=22 bash -lc 'source script/setup_common.sh; select_git_ssh_command git@github.com:loldlm1/tradingsniperpanel.com.git'`
- PASS: Command `bash -lc 'source script/setup_common.sh; git_env_prefix_for_repo git@github.com:loldlm1/tradingsniperpanel.com.git'`
- PASS: Command `bash -lc 'source script/setup_common.sh; github_ssh_host_port'`
- PASS: Command `git diff --check -- script/setup_common.sh script/setup_production.sh script/setup_staging.sh README.md docs/plans/deploy-setup-script-hardening-plan.md`

## Validation Matrix
- PASS: Local syntax validation passed for the touched deploy scripts and shared helper consumers.
- PASS: Local function probes confirm GitHub SSH now defaults to `ssh.github.com:443`.
- PASS: Local function probes confirm `GITHUB_SSH_PORT=22` still forces direct port-22 SSH behavior.
- PASS: Local diff hygiene check passed with no whitespace or merge-marker issues.
- FAIL: Manual VPS smoke validation has not yet been run for repo preflight, self-reexec from an external path, or end-to-end production/staging reruns.

## Audit Gate
- Code pattern and efficiency: PASS
- Feature behavior and goal alignment: PASS
- Tests context: FAIL
- Overall audit: FAIL
- Reason: local static and functional probes passed, but the required host-level smoke matrix is still outstanding for the real VPS environment.
