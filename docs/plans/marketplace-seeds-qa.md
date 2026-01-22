# Plan: Marketplace Seed Expansion (QA)

## Goal
Expand marketplace seed data so QA can see every marketplace product type (courses, EAs, assets, bundles, add-ons) with varied ratings/trending signals and complete metadata for the redesigned marketplace index.

## Definition of Done
- Seeded marketplace products cover single-course, single-EA, single-asset, multi-item bundles, and add-ons (EA/course/asset if desired).
- Tags, summaries, and localized fields are present so filters and cards render fully.
- Ratings/trending vary using lightweight counts (marketplace purchases and/or usage) without hiding the catalog for the QA user.
- Seeds remain idempotent and use existing fixtures for images/files.

## Constraints
- Marketplace products are one-time plans only; keep Stripe/Pay behavior intact.
- Prefer `db/seeds/shared.rb` data with dev/staging entrypoints.
- Avoid heavy data volume; keep QA-friendly counts and minimal attachments.

## Steps
1. Review existing marketplace seed definitions and available EAs/courses/assets.
2. Add marketplace product definitions for single-type items (2 per type) and keep existing bundles.
3. Extend add-on seeds to include a MarketplaceAsset add-on.
4. Add seed data for marketplace purchases to create varied ratings and 30-day trending signals, plus a small set of QA-user purchases to validate hidden items.
5. Allow local (non-Stripe) marketplace products/add-ons for the expanded QA catalog while keeping existing Stripe-backed products intact.
6. Wire new seed module into dev/staging seed entrypoints.

## Decisions
- Run expanded marketplace seeds in development and staging.
- Seed purchases for QA user (to hide a few items) and additional seed users (to drive ratings/trending).
- Target 2 marketplace products per type using varied tags.
- Add a MarketplaceAsset add-on for full type coverage.
- Keep existing Stripe-backed products; allow local (seeded) marketplace products/add-ons without hitting Stripe.
- Use a small pool of seed shoppers for purchase counts; QA user hides a bundle and an add-on for visibility checks.

## Open Questions
- None.

## Commands (discovery)
- `rg --files -g 'seeds*.rb' db` (PASS)
- `rg -n "Marketplace|marketplace" db/seeds -S` (PASS)
- `sed -n '940,1325p' db/seeds/shared.rb` (PASS)
- `sed -n '1060,1265p' db/seeds/shared.rb` (PASS)
- `sed -n '1,200p' db/seeds/development.rb` (PASS)
- `sed -n '1,200p' db/seeds/staging.rb` (PASS)
- `sed -n '1,240p' app/models/marketplace_product.rb` (PASS)
- `sed -n '1,240p' app/models/billing_plan.rb` (PASS)
- `sed -n '1,260p' app/services/marketplace/product_manager.rb` (PASS)
- `sed -n '1,260p' app/services/marketplace/catalog.rb` (PASS)
- `sed -n '1,200p' app/models/marketplace_purchase.rb` (PASS)
- `sed -n '820,960p' db/seeds/shared.rb` (PASS)
- `ls app/assets/templates/mosaic/images | head` (PASS)
- `rg --files -g 'seeds*.rb' db` (PASS)
- `rg -n "Marketplace|marketplace" db/seeds -S` (PASS)
- `sed -n '940,1325p' db/seeds/shared.rb` (PASS)
- `sed -n '1060,1265p' db/seeds/shared.rb` (PASS)
- `sed -n '1,200p' db/seeds/development.rb` (PASS)
- `sed -n '1,200p' db/seeds/staging.rb` (PASS)
- `rg -n "MarketplaceProduct|MarketplacePurchase|BillingPlan|Addon|MarketplaceAsset" docs/database_model_reference.md` (PASS)
- `sed -n '1,120p' docs/database_model_reference.md` (PASS)
- `sed -n '1,260p' app/services/marketplace/catalog.rb` (PASS)
- `sed -n '1,260p' app/services/marketplace/product_manager.rb` (PASS)
- `sed -n '1,200p' app/models/marketplace_purchase.rb` (PASS)
