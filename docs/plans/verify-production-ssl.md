# Plan: Add production SSL verification to setup script

## Goal
- Add an explicit SSL validation step with a clear success/failure message in production setup.

## Definition of Done
- Setup script validates cert/key presence and PEM integrity before finishing.
- A clear log line indicates SSL validation success (or failure) during production setup.

## Constraints
- Keep checks non-interactive and safe for automation.
- Reuse existing logging patterns in setup scripts.

## Steps
1. Add a helper in `script/setup_common.sh` to validate cert/key files.
2. Call the helper from `script/setup_production.sh` as part of final verification.
3. Update plan with decisions and commands.

## Decisions
- Validate PEM integrity with `openssl x509` plus BEGIN/END count to catch malformed chains.
- Validate private key using `openssl pkey` to catch invalid/encrypted keys.

## Commands (PASS/FAIL)
- PASS: apply_patch script/setup_common.sh
- PASS: apply_patch script/setup_production.sh

## Open Questions
- None.
