# Master Admin Features (Developer Guide)

This short guide lists admin-only capabilities that require the `master_admin` role. These areas are intentionally restricted because they affect billing, entitlements, and payout logic.

## Restricted areas
- **Expert Advisors**: create/edit/delete
- **Expert Advisor Bundles**: create/edit/delete
- **Courses**: create/edit/delete
- **Marketplace Assets**: create/edit/delete
- **Marketplace Products**: create/edit/delete (affects Stripe one‑time products)
- **Billing Plans**: create/edit/delete (affects Stripe subscription products)
- **Plan Entitlements**: create/edit/delete for EA/Course/Asset access
- **Revenue Split Payouts**: create/edit (record paid periods)

## Operational notes
- **Stripe sync**
  - Billing Plans and Marketplace Products can create/update Stripe Products/Prices.
  - Changing price/interval on a plan creates a new Stripe Price and deactivates the old one.
- **Add-on safety**
  - Marketplace Asset add-ons require an existing base product.
  - EA add-on keys must be covered by bundle files for all combinations.
- **Roles**
  - Only `master_admin` can grant or edit admin-level roles.

## Where to review code
- Access gates live in ActiveAdmin resources (`app/admin/...`).
- Stripe sync for subscriptions: `app/services/billing/plan_creator.rb`.
- Stripe sync for marketplace products: `app/services/marketplace/product_manager.rb`.
