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
1. Inspect `app/views/marketplace/show.html.erb` to confirm current grid/flex structure and ordering.
2. Adjust layout classes/structure so the two-column desktop layout matches the original mockup while preserving mobile order.
3. Add a responsive-only `hr` after the product description (visible on small screens, hidden on lg+).
4. Verify ordering and divider visibility in light/dark themes at small and lg+ widths.

## Open Questions
None.

## Decisions
- Match the responsive patterns from `mosaic-html/dashboard_marketplace_show.html` (keep `lg` breakpoint).
- Mobile-only divider uses the same separator styling as other `hr` elements.
- Layout order: small screens = content → sidebar → related; large screens = content left + sidebar right, related below content.

## Commands
- PASS: rg -n "Frequently Bought|Related" mosaic-html/dashboard_marketplace_show.html
- PASS: rg -n "Page content|Sidebar" mosaic-html/dashboard_marketplace_show.html
- PASS: sed -n '1030,1115p' mosaic-html/dashboard_marketplace_show.html
- PASS: sed -n '1080,1205p' mosaic-html/dashboard_marketplace_show.html
- PASS: sed -n '1205,1320p' mosaic-html/dashboard_marketplace_show.html
- PASS: sed -n '1330,1395p' mosaic-html/dashboard_marketplace_show.html
- PASS: sed -n '1395,1465p' mosaic-html/dashboard_marketplace_show.html
- PASS: sed -n '1,260p' app/views/marketplace/show.html.erb
