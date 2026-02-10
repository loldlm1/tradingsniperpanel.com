# Sniper Production Seeds Refactor

## Goal
- Refactor seeds so production defaults to a launch-safe mirror dataset (Sniper + Basic only), while development/staging keep full QA seeds by default.
- Align Sniper seed sources to `docs_eas/sniper_advanced_panel` assets and guides, update EN/ES plan copy, and remove deprecated README docs-path guidance.

## Definition of Done
- `db:seed` uses profile-aware behavior:
- `production` defaults to `prod_mirror`.
- `staging` and `development` default to full QA seeds.
- `SEED_PROFILE=prod_mirror` overrides defaults.
- `script/reset_staging_db.sh --prod-mirror-seed` runs seed commands with `SEED_PROFILE=prod_mirror` for that invocation only.
- Prod mirror seeds only create the Sniper EA and Basic subscription plans (`basic_monthly=2000`, `basic_annual=18000`).
- Sniper bundle source is `docs_eas/sniper_advanced_panel/sniper_advanced_panel_ea.zip`.
- Sniper guides seed from `sniper_advanced_panel_guide_es.md` and EN translated counterpart.
- Landing/dashboard EN/ES pricing copy reflects current Basic plan messaging.
- README no longer references deprecated `public/docs/sniper_advanced_panel` exposure.
- Specs cover profile routing and pricing seed amounts; targeted rspec suite passes.

## Constraints
- Keep seed operations idempotent.
- Avoid persistent environment changes for seed profile selection.
- Do not remove QA seed capabilities for staging/development defaults.
- Keep changes scoped to requested launch preparation and docs cleanup.

## Steps
1. Add plan profile primitives and seed runner wiring (`db/seeds.rb`, new seed helper files, env seed entrypoints).
2. Update shared seed modules for profile-aware EA and billing definitions.
3. Update staging reset script to support `--prod-mirror-seed`.
4. Add EN Sniper guide file and wire guide paths/bundle attachment.
5. Update EN/ES pricing copy for landing and dashboard sections.
6. Remove deprecated README docs-path references and document seed profile behavior.
7. Add/update specs and run targeted validation.

## Open Questions
- None blocking.

## Decisions
- Use `SEED_PROFILE=prod_mirror` as the explicit override key.
- Keep `staging` and `development` default seed profile as QA/full dataset.
- Implement `--prod-mirror-seed` as a non-persistent env override only for seeded script actions.
- In `prod_mirror`, prune stale records by soft-deleting all non-target EAs and deactivating all non-target subscription plans before reseeding.

## Command Log (PASS/FAIL)
- PASS: `ls -la docs/plans; test -f docs/plans/sniper-production-seeds-refactor.md && sed -n '1,220p' docs/plans/sniper-production-seeds-refactor.md || true`
- PASS: `git status --short`
- PASS: `bundle exec rspec spec/seeds/profiles_spec.rb spec/seeds/runner_spec.rb spec/services/billing/pricing_catalog_spec.rb spec/services/marketing/neon_landing_pricing_spec.rb`
- PASS: `bundle exec rspec spec/seeds`
- PASS: `bundle exec rspec spec/requests/home_pricing_cta_spec.rb`
- PASS: `bash -n script/reset_staging_db.sh`
- PASS: `bash script/reset_staging_db.sh --help | sed -n '1,40p'`
- PASS: `ruby -e 'require "yaml"; %w[config/locales/en.yml config/locales/es.yml config/locales/dashboard.en.yml config/locales/dashboard.es.yml].each { |f| YAML.load_file(f); puts "OK #{f}" }'`
