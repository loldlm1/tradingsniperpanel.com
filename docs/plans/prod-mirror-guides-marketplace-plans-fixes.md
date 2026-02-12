# Plan: Prod Mirror Guides, Marketplace Markdown, and Plans Price Key Robustness

## Goal
- Fix prod-mirror guide and plans regressions so seeded guide content matches official files, markdown media does not autoplay, marketplace overview renders as markdown, and `/dashboard/plans` handles underscore tier keys like `pandora_pro_monthly` without UI breakage.

## Definition of Done
- `prod_mirror` guide seeding does not inject synthetic intro/outro media tokens.
- Guide media embeds generated from markdown do not autoplay; playback starts only on user interaction.
- Marketplace product overview renders markdown (headings/lists/formatting), not raw markdown text formatting.
- `/dashboard/plans?price_key=pandora_pro_monthly` renders plan prices and layout correctly.
- Invalid or ambiguous `price_key` parsing silently falls back to default interval (no FE breakage).
- Targeted specs covering seeds, markdown rendering, marketplace overview rendering, and plans flow pass.

## Constraints
- Keep seed media-token behavior change scoped to `prod_mirror` only.
- Keep fallback behavior silent for invalid `price_key` interval parsing.
- Avoid changing billing amounts/tier definitions/checkout business logic.
- Keep changes focused to reported issues only.

## Steps
1. Update `db/seeds/shared.rb` guide loading to keep `prod_mirror` content 1:1 with source files.
2. Update `app/services/markdown_renderer.rb` to remove autoplay semantics from video and YouTube embeds.
3. Render marketplace show overview markdown via `MarkdownRenderer` instead of `simple_format`.
4. Harden interval parsing in plans/landing views for underscore tier keys and keep silent interval fallback.
5. Add/update focused specs for seeds, markdown rendering, marketplace overview markdown, and plans query-param behavior.
6. Run targeted test suite and document PASS/FAIL results.

## Open Questions
- None.

## Decisions
- Seed media-token removal applies to `prod_mirror` only.
- Invalid plan interval parsing should silently fall back to the default interval.

## Command Log (PASS/FAIL)
- PASS: `git status --short`
- PASS: `sed -n '1,260p' spec/factories/billing_plans.rb`
- PASS: `ls -1 docs/plans`
- PASS: `git diff -- db/seeds/shared.rb app/services/markdown_renderer.rb app/controllers/marketplace_controller.rb app/views/marketplace/show.html.erb`
- PASS: `git diff -- app/views/dashboards/plans.html.erb app/views/templates/neon/pages/home.html.erb`
- PASS: `git diff -- spec/seeds/runner_spec.rb spec/services/markdown_renderer_spec.rb spec/requests/marketplace_spec.rb spec/requests/plan_persistence_spec.rb spec/requests/home_pricing_cta_spec.rb`
- PASS: `bundle exec rspec spec/seeds/runner_spec.rb spec/services/markdown_renderer_spec.rb spec/requests/marketplace_spec.rb spec/requests/plan_persistence_spec.rb spec/requests/home_pricing_cta_spec.rb spec/requests/subscription_upgrade_spec.rb`
