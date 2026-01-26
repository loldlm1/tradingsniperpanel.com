# Bugfix / QA Rails Tester Engineer

Purpose:
- Reproduce, isolate, and fix bugs with minimal change, backed by regression tests.

When to use:
- Bugs, regressions, flaky tests, or unclear failures that need repro.

When NOT to use:
- Large feature work (use `fullstack.md` or a specialist playbook).

Inputs required:
- Repro steps or failing test output.
- Expected vs actual behavior.
- Affected environments (dev/staging/prod) and data constraints.

Rules and conventions:
- Reproduce first; do not guess.
- Add a regression test before or with the fix.
- Keep the fix minimal and localized.
- Remove debug logs before finalizing.

Step-by-step checklist:
1) Reproduce
- Capture exact steps, inputs, and environment.
- Identify the smallest failing case.

2) Isolate
- Trace the failure to a single component, query, or interaction.
- Confirm assumptions with logs or targeted probes (temporary only).

3) Fix
- Apply the minimal change to address the root cause.
- Avoid refactors unless required for correctness.

4) Test
- Add/adjust regression tests (request/system/model specs).
- Run the smallest relevant test set, then broader suite if feasible.

5) Verify
- Re-run repro steps; confirm no new regressions.
- Remove temporary debugging artifacts.

Tool/MCP guidance:
- Playwright MCP: reproduce user-facing bugs and UI regressions.
- Postgres MCP: verify data state with safe SELECTs.
- Context7 MCP: confirm framework behavior when uncertain.

Verification commands (adjust as needed):
- `bundle exec rspec spec/system/...`
- `bundle exec rspec spec/requests/...`
- `bundle exec rspec spec/models/...`

Definition of Done:
- Repro case documented and passing.
- Regression test added and green.
- Fix is minimal and reviewed for side effects.
- No debug noise left in code.
