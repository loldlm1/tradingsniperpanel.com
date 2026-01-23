# Plan: Marketplace Show Layout Fix

## Goal
Restore the marketplace show layout so large screens match the intended two-column design, while keeping the mobile stacking order (content -> checkout -> related) and adding a clear divider after the product description on small screens.

## Definition of Done
- On lg+ screens, the checkout sidebar renders to the right of the main content (as before) and related items render below the main content column.
- On small screens, the order is: main content, checkout sidebar, related items.
- A visible divider appears after the product description on small screens only.
- Mosaic HTML comment blocks remain intact and layout changes are minimal.

## Constraints
- Follow `docs/cruip_template_guide.md` and keep existing section comments.
- Avoid over-complex layout changes; prefer class or structural adjustments in `app/views/marketplace/show.html.erb`.

## Steps
1. Inspect `app/views/marketplace/show.html.erb` and Mosaic patterns to confirm which responsive classes are available.
2. Align the container layout with Mosaic (`flex flex-col lg:flex-row` + spacing) to restore the large-screen two-column layout.
3. Render the related section so mobile order remains content → sidebar → related while desktop keeps related under content (likely via a responsive-only variant).
4. Keep the mobile-only `hr` after the description.
5. Verify ordering and divider visibility in light/dark themes at small and lg+ widths.

## Open Questions
None.

## Decisions
- Match the responsive patterns from `mosaic-html/dashboard_marketplace_show.html` (keep `lg` breakpoint).
- Mobile-only divider uses the same separator styling as other `hr` elements.
- Layout order: small screens = content → sidebar → related; large screens = content left + sidebar right, related below content.
- Render the related section twice, using responsive visibility classes (`hidden lg:block` and `lg:hidden`) to avoid rebuilding Tailwind.

## Commands
- PASS: sed -n '1,200p' docs/plans/marketplace-show-layout-fix.md
- PASS: rg -n "Frequently Bought|Related" mosaic-html/dashboard_marketplace_show.html
- PASS: rg -n "Page content|Sidebar" mosaic-html/dashboard_marketplace_show.html
- PASS: sed -n '1030,1115p' mosaic-html/dashboard_marketplace_show.html
- PASS: sed -n '1080,1205p' mosaic-html/dashboard_marketplace_show.html
- PASS: sed -n '1205,1320p' mosaic-html/dashboard_marketplace_show.html
- PASS: sed -n '1330,1395p' mosaic-html/dashboard_marketplace_show.html
- PASS: sed -n '1395,1465p' mosaic-html/dashboard_marketplace_show.html
- PASS: sed -n '1,260p' app/views/marketplace/show.html.erb
- PASS: rg -n "lg:hidden" mosaic-html/dashboard_marketplace_show.html | head
- PASS: rg --files -g 'tailwind*'
- FAIL: rg --files -g 'tailwind.config.*'
- PASS: rg -n "tailwind" app/assets/stylesheets app/assets/builds config | head
- PASS: ls app/assets
- PASS: ls app/assets/stylesheets
- PASS: ls app/assets/tailwind
- PASS: sed -n '1,200p' app/assets/tailwind/application.css
- FAIL: rg -n "\\.lg\\\\:grid" app/assets/builds/tailwind.css
- FAIL: rg -n "\\.lg\\\\:flex-row" app/assets/builds/tailwind.css
- PASS: rg -n "flex-row" app/assets/builds/tailwind.css | head
- PASS: rg -n "grid-cols-2" app/assets/builds/tailwind.css | head
- PASS: rg -n "minmax\\(0,1fr\\).*18rem" app/assets/builds/tailwind.css
- PASS: rg -n "grid-template-columns:minmax\\(0,1fr\\) 18rem" app/assets/builds/tailwind.css
- FAIL: rg -n "\\.lg\\\\:pr-80" app/assets/builds/tailwind.css
- PASS: rg -n "lg:flex-row|lg:grid|lg:space-x-8|lg:space-x-" app/views app/assets
- FAIL: rg -n "lg\\\\:grid-cols-3" app/assets/builds/tailwind.css
- PASS: rg -n "grid-cols-3" app/assets/builds/tailwind.css | head
- PASS: rg -n "min-width:64rem" app/assets/builds/tailwind.css | head
- PASS: sed -n '1,280p' app/views/marketplace/show.html.erb
