# Seed Bundle Checksum Reattach

## Goal
Ensure seed reruns in deploy workflows refresh EA bundle attachments when the source bundle file content changed.

## Definition of Done
- `Seeds::ExpertAdvisors.attach_bundle` compares source file checksum vs attached blob checksum.
- If checksum differs, the old attachment is replaced with the new file.
- If checksum matches, no reupload occurs.
- The same behavior is applied to `Seeds::ExpertAdvisorBundles.attach_bundle`.
- Existing filename normalization behavior remains intact.

## Constraints
- Keep seed operations idempotent.
- No destructive DB changes or schema changes.
- Keep change scoped to seed attachment logic.

## Steps
1. Add checksum helper(s) in `db/seeds/shared.rb`.
2. Update `Seeds::ExpertAdvisors.attach_bundle` to reattach only when checksum differs.
3. Update `Seeds::ExpertAdvisorBundles.attach_bundle` with the same checksum-aware behavior.
4. Run lightweight verification (syntax check).
5. Record decisions + command results (PASS/FAIL).

## Open Questions
- None.

## Execution Log
- Decision: Use MD5 checksum (Base64-encoded) from source bundle file and compare to ActiveStorage blob checksum.
- Decision: On checksum mismatch, purge existing attachment and reattach new bundle; on match, skip reupload and only normalize filename.
- Command: `ls -la docs/plans && rg --files docs/plans` -> PASS
- Command: `cat > docs/plans/seed-bundle-checksum-reattach.md` -> PASS
- Command: `sed -n '1,80p' db/seeds/shared.rb && sed -n '240,310p' db/seeds/shared.rb && sed -n '2350,2415p' db/seeds/shared.rb` -> PASS
- Command: `bundle exec ruby -c db/seeds/shared.rb` -> PASS
