# Trading Sniper Panel — Admin Guide (EN)

This guide helps client and internal admins manage the Trading Sniper Panel catalog, subscriptions, and access. It focuses on the ActiveAdmin back office and the main workflows used to publish EAs, courses, and marketplace products.

> Note: Screenshots are currently in Spanish only. They still match the same screens/fields.

## Table of contents
1. Access + navigation basics
2. Data model map (how things connect)
3. Expert Advisors (EAs)
4. EA bundles
5. EA add-ons (one-time)
6. Courses
7. Course modules + lessons
8. Course add-ons (one-time)
9. Marketplace assets
10. Marketplace products (one-time)
11. Billing plans (subscriptions)
12. Plan entitlements (EA/Course/Asset access)
13. Manual billing (transactions + subscriptions)
14. Users
15. Revenue split rules + payouts
16. Launch checklists
17. Troubleshooting

---

## 1) Access + navigation basics
- **Admin URL**: `/admin` (requires an admin account).
- **Language**: Use the account’s preferred locale; the UI supports EN/ES.
- **Filters**: Each screen has filters in the sidebar for search and scoping.
- **Actions**: Use `New`, `Edit`, `Delete`, and bulk actions where available.
- **Uploads**: File/image uploads are stored via Active Storage; always save after attaching.

Screenshot (ES):
![Admin dashboard](images/es-01-admin-dashboard.png)

---

## 2) Data model map (how things connect)
Use this to understand dependencies before creating records:
- **Expert Advisors** connect to **Billing Plans** via **Plan Entitlements** (subscriptions) and to **Marketplace Products** for one-time sales.
- **Marketplace Products** create **Billing Plans (one-time)** automatically and can grant access to EAs, Courses, or Marketplace Assets.
- **Add-ons** are special Marketplace Products that extend an EA/Course/Asset.
- **Courses** have **Modules** and **Lessons** and can be granted via subscriptions or one-time purchases.
- **Marketplace Assets** are one-time downloadable items (PDFs, templates, etc.).
- **Entitlements** live in three admin screens: Billing Plan Entitlements, Course Plan Entitlements, and Asset Plan Entitlements.

Screenshot (ES):
![Data map](images/es-02-data-map.png)

---

## 3) Expert Advisors (EAs)
**Where:** Admin → Expert Advisors

**Create an EA**
1. Click `New Expert Advisor`.
2. Fill in: name, description, type (EA/tool/indicator/script), tier rank (ordering), trial enabled, tags.
3. Upload the EA bundle file (`ea_files`).
4. Add EN/ES guides in the “Guides” section.
5. Save.

**Tips**
- `ea_id` is auto-generated and immutable once created.
- Use tags for filtering and marketplace discovery.

Screenshot (ES):
![Expert Advisor form](images/es-03-expert-advisor-form.png)

---

## 4) EA bundles
**Where:** Admin → Expert Advisor Bundles

Use bundles to map add-on combinations to downloadable files.

**Create a bundle**
1. Click `New Expert Advisor Bundle`.
2. Select the Expert Advisor.
3. Enter required add-on keys (comma-separated). The `bundle_key` is computed automatically.
4. Upload the bundle file and set active/sort order.
5. Save.

**Why it matters**
If add-ons are sold, every required add-on combination needs a bundle file. The EA show page includes a bundle coverage panel to highlight missing combinations.

Screenshot (ES):
![EA bundles form](images/es-04-ea-bundles.png)

---

## 5) EA add-ons (one-time)
**Where:** Admin → Marketplace Products

Add-ons are Marketplace Products that extend a specific EA.

**Create an EA add-on product**
1. Click `New Marketplace Product`.
2. Fill product details (slug, status, sort order, title, summary, description, image).
3. Set pricing (amount, currency, Stripe IDs if needed).
4. In **Add-on**, choose the target EA and add-on key.
5. Save.

**After saving**
- The add-on is now tied to the EA and used for bundle coverage.
- If bundle coverage shows missing keys, add bundle files in EA Bundles.

Screenshot (ES):
![EA add-on product](images/es-05-ea-addon-product.png)

Diagram:
![EA, add-ons, and bundles](images/es-18-ea-bundles-addons.png)

---

## 6) Courses
**Where:** Admin → Courses

**Create a course**
1. Click `New Course`.
2. Set slug, status, category, position, and published date.
3. Add EN/ES title, summary, and description.
4. Add tags for discovery.
5. Save.

**Tip**: Keep `status` as `draft` until modules/lessons are ready.

Screenshot (ES):
![Course form](images/es-06-course-form.png)

---

## 7) Course modules + lessons
**Where:** Admin → Course Modules / Course Lessons

**Create modules**
1. Go to Course Modules → `New`.
2. Select course, set position, title, and summary.
3. Save.

**Create lessons**
1. Go to Course Lessons → `New`.
2. Select module, set position/title/summary.
3. Add lesson body (Markdown), Stream UID, duration seconds.
4. Save.

Screenshot (ES):
![Course modules form](images/es-07-course-modules.png)
![Course lessons form](images/es-08-course-lessons.png)

---

## 8) Course add-ons (one-time)
**Where:** Admin → Marketplace Products

Use Marketplace Products to sell one-time course access or add-ons.

**Create a course add-on**
1. Create a Marketplace Product.
2. In **Entitlements**, select the course to grant access.
3. (Optional) In **Add-on**, choose the course and define the add-on key.
4. Save.

Screenshot (ES):
![Course add-on](images/es-09-course-addon.png)

---

## 9) Marketplace assets
**Where:** Admin → Marketplace Assets

**Create an asset**
1. Click `New Marketplace Asset`.
2. Set slug, status, sort order.
3. Fill EN/ES title, summary, description.
4. Upload the file.
5. Save.

Screenshot (ES):
![Marketplace asset form](images/es-10-marketplace-asset.png)

---

## 10) Marketplace products (one-time)
**Where:** Admin → Marketplace Products

Marketplace Products are one-time items that create a Billing Plan and grant access.

**Create a product**
1. Click `New Marketplace Product`.
2. Fill product details (including status/sort order) and image.
3. Set pricing (amount/currency + Stripe IDs if required).
4. Add **Entitlements** (EAs, Courses, Assets) that the purchase unlocks.
5. Configure **Add-on** only if this product extends another item.
6. Save.

**Notes**
- This flow creates a one-time Billing Plan automatically.
- For marketplace asset add-ons, a base product must exist first.

Screenshot (ES):
![Marketplace product form](images/es-11-marketplace-product.png)

---

## 11) Billing plans (subscriptions)
**Where:** Admin → Billing Plans

Use Billing Plans for subscription tiers (e.g., basic/monthly).

**Create a subscription plan**
1. Click `New Billing Plan`.
2. Set key (must match `tier_interval`, e.g., `basic_monthly`).
3. Fill name, kind `subscription`, tier, interval, interval count, amount, currency, active, sort order.
4. Add Stripe Product/Price IDs if applicable.
5. Save.

**Notes**
- Subscription plans require `tier`, `interval`, and `interval_count`.
- Changing amount/interval may create a new Stripe price and deactivate the old one.

Screenshot (ES):
![Billing plan form](images/es-12-billing-plans.png)

Diagram:
![Purchase flow (subscription vs one-time)](images/es-17-purchase-flow.png)

---

## 12) Plan entitlements (EA/Course/Asset access)
**Where:** Admin →
- Billing Plan Entitlements (EAs)
- Course Plan Entitlements (Courses)
- Asset Plan Entitlements (Marketplace Assets)

Use entitlements to define what a plan grants.

**Create an entitlement**
1. Click `New` in the entitlement screen.
2. Choose the Billing Plan and the target EA/Course/Asset.
3. Save.

**Recommended flow**
1. Create or confirm Billing Plans.
2. Add entitlements for each subscription plan.
3. For one-time products, manage entitlements inside the Marketplace Product form.
4. Verify access in the public dashboard or by checking entitlements lists.

Screenshot (ES):
![Plan entitlements](images/es-13-plan-entitlements.png)

Diagram:
![Entitlements by plan vs product](images/es-19-entitlements-map.png)

---

## 13) Manual billing (transactions + subscriptions)
**Where:** Admin → Manual Transactions / Manual Subscriptions

Use these to record offline payments.

**Manual transaction (one-time)**
1. Click `New Manual Transaction`.
2. Choose user + billing plan (one-time).
3. Enter amount, currency, paid at, payment method, reference.
4. Save.

**Manual subscription**
1. Click `New Manual Subscription`.
2. Choose user + billing plan (subscription).
3. Enter start/end dates, paid at, status, payment method.
4. Save.

Screenshot (ES):
![Manual billing form](images/es-14-manual-billing.png)

---

## 14) Users
**Where:** Admin → Users

**Create or edit users**
- Set email, name, role, preferred locale, time zone.
- Passwords are only required on create.

**Role notes**
Some actions may be restricted by role. If a button is missing, contact your internal admin team.

Screenshot (ES):
![Users index](images/es-15-users.png)

---

## 15) Revenue split rules + payouts
**Where:** Admin → Revenue Split Rules / Revenue Split Payouts

Use these to track revenue split logic and payout records.

**Revenue split rule**
- Defines the company/client percentages for a period.

**Payouts**
- Record and track payouts per period.

Screenshot (ES):
![Revenue split rules](images/es-16-revenue-splits.png)

---

## 16) Launch checklists

### A) Launch a new EA
1. Create the Expert Advisor.
2. Upload the EA file and guides.
3. Create add-on Marketplace Products (if needed).
4. Add required bundle files.
5. Link entitlements to subscription plans.

### B) Publish a new course
1. Create the Course.
2. Add Modules and Lessons.
3. Create a Marketplace Product (one-time) if needed.
4. Link entitlements to subscription plans.

### C) Launch a marketplace product
1. Create the Marketplace Product with pricing.
2. Add entitlements (EA/Course/Asset).
3. Add add-on configuration if it’s an extension.

---

## 17) Troubleshooting
- **Missing item in dropdown**: Ensure the record is created and active; refresh the form.
- **Bundle coverage missing keys**: Add the missing add-on bundle files.
- **Asset add-on error**: Create a base marketplace product for the asset first.
- **Course not visible**: Confirm status is `published` and `published_at` is set.
- **Stripe errors**: Verify `STRIPE_PRIVATE_KEY` and Stripe IDs.

---

## Appendix: Screenshot file list (ES)
Place screenshots here: `saas_admin_guide/images/`
- `es-01-admin-dashboard.png`
- `es-02-data-map.png`
- `es-03-expert-advisor-form.png`
- `es-04-ea-bundles.png`
- `es-05-ea-addon-product.png`
- `es-06-course-form.png`
- `es-07-course-modules.png`
- `es-08-course-lessons.png`
- `es-09-course-addon.png`
- `es-10-marketplace-asset.png`
- `es-11-marketplace-product.png`
- `es-12-billing-plans.png`
- `es-13-plan-entitlements.png`
- `es-14-manual-billing.png`
- `es-15-users.png`
- `es-16-revenue-splits.png`
