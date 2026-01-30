# Master Admin Features (Developer Guide)

This short guide lists admin-only capabilities that require the `master_admin` role. The current policy is that admins can CRUD all resources; only role changes are restricted.

## Restricted areas
- **User roles**: only `master_admin` can change a user’s `role` (including assigning `admin` or `master_admin`).

## Operational notes
- **Stripe sync**
  - Billing Plans and Marketplace Products can create/update Stripe Products/Prices.
  - Changing price/interval on a plan creates a new Stripe Price and deactivates the old one.
- **Add-on safety**
  - Marketplace Asset add-ons require an existing base product.
  - EA add-on keys must be covered by bundle files for all combinations.
- **Roles**
  - `admin` users can create/edit users but cannot change the `role` field.
  - `master_admin` can assign or update all roles.

## Where to review code
- Role change gates live in `app/services/admin/users/role_guard.rb` and `app/admin/users.rb`.
- Stripe sync for subscriptions: `app/services/billing/plan_creator.rb`.
- Stripe sync for marketplace products: `app/services/marketplace/product_manager.rb`.
