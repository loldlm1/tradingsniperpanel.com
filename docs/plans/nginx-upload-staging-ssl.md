# Plan: Nginx upload limit + staging SSL handling

## Goal
- Allow 10MB uploads via Nginx.
- Ensure staging deploy succeeds without SSL files (staging is non-SSL).

## Definition of Done
- Nginx config sets `client_max_body_size` to 10m for app servers.
- Staging setup script does not fail when SSL files are missing.
- Production SSL validation remains enforced.

## Constraints
- Keep changes minimal and consistent with existing deploy scripts.
- Avoid breaking production SSL checks.

## Steps
1. Update Nginx config generation to include `client_max_body_size 10m`.
2. Adjust staging setup to call Nginx config without requiring SSL.
3. Summarize changes and verification steps.

## Decisions
- Set `client_max_body_size 10m` in the production TLS and staging server blocks to scope limits to app traffic.
- Add a staging log line clarifying SSL is optional and prod block is skipped when certs are missing.

## Commands (PASS/FAIL)
- PASS: apply_patch script/setup_common.sh
- PASS: apply_patch script/setup_staging.sh

## Open Questions
- None.
