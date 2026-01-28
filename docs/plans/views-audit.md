# Views Audit Plan

## Goal
Audit all view-layer templates and components to align with Rails view hygiene and app conventions while keeping the current design intact, then run the full RSpec suite to confirm no regressions.

## Definition of Done
- All in-scope views reviewed and any necessary refactors applied (partials/components/helpers/I18n keys) without visual/layout changes.
- No inline `<style>` or `<script>` added; new assets hooked via the existing pipeline/importmap.
- I18n keys added for user-facing copy that is currently hardcoded in views, with EN/ES coverage where applicable.
- Repeated UI patterns extracted into partials/components with clear naming.
- Full test suite runs and is green.

## Constraints
- Scope limited to ERB views; exclude admin views.
- Prioritize landing, dashboard, and Devise views.
- Keep layout and styling intact; avoid markup changes that could alter visual output.
- Follow `AGENTS.md` engineering notes for view hygiene and assets.
- Avoid modifying vendor/template assets under `app/assets/templates/...`.
- Keep controllers thin; move logic to helpers/POROs only if view audit requires it.
- Use `I18n` for copy; no string concatenation; add EN+ES keys for touched views.

## Steps
1. Inventory ERB view files under `app/views/**`, excluding admin; confirm landing, dashboard, and Devise areas are covered.
2. Review views for: repeated patterns → extract partials/components; hardcoded strings → move to I18n (EN+ES); inline scripts/styles → move to assets; complex logic → move to helpers/partials.
3. Apply refactors incrementally and keep diffs small to avoid visual regressions.
4. Run full RSpec suite; fix any regressions tied to view changes.
5. Summarize changes and archive the plan after completion.

## Decisions
- Scope: ERB views only; exclude admin. Priority areas are landing, dashboard, and Devise.
- I18n: add EN+ES keys for all touched views when required.
- Design-system markdown templates are reference-only for now.
- Delivery: single pass.

## Execution Log (decisions + commands)
- 2026-01-28: `ls` (PASS)
- 2026-01-28: `cat /home/loldlm/.agents/skills/rails-expert/SKILL.md` (PASS)
- 2026-01-28: `rg --files app/views` (PASS)
- 2026-01-28: `rg --files config/locales` (PASS)
- 2026-01-28: `rg -n "<style|<script" app/views` (PASS)
- 2026-01-28: `rg -n ">[^<%]*[A-Za-z][^<%]*<" app/views` (PASS)
- 2026-01-28: `rg -n "x-cloak" app/assets/templates` (PASS)
- 2026-01-28: `bundle exec rspec` (FAIL - timeout)
- 2026-01-28: `bundle exec rspec` (PASS)
