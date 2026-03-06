# Production Pricing Refresh And Landing Discount Banner

## Goal
Update production pricing/tier presentation and add a simple env-driven discount banner on the landing page (`/`) while preserving existing internal billing keys and Stripe/Pay architecture.

## Definition of Done
- Prod mirror subscription prices are:
  - `basic_monthly` = `$24.99` (Tier 1 display: Sniper Panel)
  - `fibonacci_elite_monthly` = `$69.99` (Tier 2 display: Fibonacci, includes Sniper access)
  - `pandora_pro_monthly` = `$99.99` (Tier 3 display: Pandora Box, includes Sniper + Fibonacci access)
- Annual prod mirror prices use a 35% discount from monthly-derived yearly total.
- Prod mirror EA rank order is Sniper -> Fibonacci -> Pandora.
- Pandora one-time marketplace product is `$599.00` and grants Pandora only.
- Add-ons keep their current prices.
- Landing page renders a discount banner only when:
  - `DISCOUNT_BANNER_CODE` is present
  - `DISCOUNT_BANNER_PERCENT` parses as a positive percent from either `N` or `N%`.
- EN/ES copy reflects new display plan names.
- Relevant specs pass for seed outputs and banner behavior.
- Audit Gate reports PASS for:
  - code pattern and efficiency
  - feature behavior and goal alignment
  - tests context.

## Constraints
- Keep internal tier keys unchanged: `basic`, `fibonacci_elite`, `pandora_pro`.
- Keep implementation Rails-conventional: thin controllers, reusable services/partials, I18n-driven copy.
- Do not automate Stripe coupon creation for banner in this task.
- Keep changes scoped to this feature and avoid unrelated refactors.

## Steps
1. Update prod mirror seed pricing, tier order, annual multiplier, EA rank order, and Pandora one-time price.
2. Update EN/ES locale display names and related tier copy without key migrations.
3. Implement env parser/service for discount banner and render a shared banner partial on landing home only.
4. Document new env vars in `.envrc.example` and README env references.
5. Update/add specs for:
   - prod mirror seed expectations
   - banner visibility/parsing behavior.
6. Run targeted specs.
7. Run Audit Gate and record PASS/FAIL.

## Open Questions
- None. Inputs were confirmed by user on 2026-03-06.

## Decisions
- Keep internal keys and change only display names.
- Annual pricing is 35% discount from monthly-derived yearly totals.
- `DISCOUNT_BANNER_PERCENT` accepts both `15` and `15%`.
- Landing banner scope is `/` only.
- Pandora one-time purchase is standalone (no bundled Sniper/Fibonacci entitlement).

## Command Log (PASS/FAIL)
- `PASS` `rg -n "prod_mirror_definitions|PROD_MIRROR_TIER_DEFINITIONS|PROD_MIRROR_INTERVAL_DEFINITIONS|ea_pandora_box|expand_tiers_for_profile" db/seeds/shared.rb app/services -S`
- `PASS` `bundle exec rspec spec/seeds/runner_spec.rb spec/requests/home_pricing_cta_spec.rb spec/services/marketing/discount_banner_spec.rb`
- `PASS` `bundle exec rspec spec/services/marketing/neon_landing_pricing_spec.rb spec/services/billing/pricing_catalog_spec.rb`

## Audit Gate
- `PASS` Code pattern and efficiency: pricing logic remains seed-driven; discount banner logic isolated in a small service + partial, controller stays thin.
- `PASS` Feature behavior and goal alignment: prod mirror prices/ranks/order updated; annual multiplier set for 35% off; Pandora one-time price updated; banner gated by env and scoped to `/`.
- `PASS` Tests context: updated seed + request specs and added service spec for banner parsing/visibility; targeted relevant pricing specs pass.
