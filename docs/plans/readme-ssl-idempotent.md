# Plan: Make SSL install step idempotent

## Goal
- Make README SSL instructions safe to rerun and avoid malformed PEM chains.

## Definition of Done
- README step 7 uses idempotent commands (`unzip -o`, rebuilds fullchain each run).
- Explicitly ensures newline separation between certs in `fullchain.crt`.
- Keeps guidance concise and production-focused.

## Constraints
- Keep changes scoped to README.
- Maintain current file paths and naming.

## Steps
1. Update SSL step commands to overwrite/rebuild on rerun and enforce PEM newlines.
2. Add guidance for private key filename differences and missing key in bundle.
3. Summarize changes.

## Decisions
- Use `unzip -o` and `install -m 600` for idempotent, secure file updates.
- Use `awk "1"` to rebuild `fullchain.crt` with normalized newlines between certs.
- Allow private key to be supplied from a separate path when the bundle doesn't include it.

## Commands (PASS/FAIL)
- PASS: apply_patch README.md
- PASS: apply_patch README.md (private key guidance)
- PASS: apply_patch README.md (local VPS cert folder guidance)

## Open Questions
- None.
