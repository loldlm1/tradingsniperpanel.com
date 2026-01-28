# Dashboard Page Overrides

> **PROJECT:** Trading Sniper Panel
> **Generated:** 2026-01-28
> **Page Type:** Mosaic Dashboard

> ⚠️ **IMPORTANT:** Rules in this file **override** the Master file (`design-system/trading-sniper-panel/MASTER.md`).
> Only deviations from the Master are documented here. For all other rules, refer to the Master.

---

## Page-Specific Rules

### Layout Overrides
- **Shell:** Left sidebar + topbar; sidebar collapses on mobile, persists on desktop.
- **Grid:** 12-column grid, 24px gutters; stack to single column at <768px.
- **Sections:** 1) Page header, 2) KPI row, 3) Charts/insights, 4) Tables/lists, 5) Secondary panels.
- **Density:** Medium-high; prioritize scannability over whitespace.

### Navigation Overrides
- **Sidebar groups:** Emphasize active state with clear accent + subtle background (no heavy gradients).
- **Icon rhythm:** Keep icon sizes consistent (16–20px) and aligned to text baselines.

### Color Overrides
- **Strategy:** Use Master palette; apply accent selectively for active nav, primary actions, and KPI highlights.
- **Dark mode:** Supported; maintain AA contrast and visible borders.

### Typography Overrides
- **Heading scale:** Reduce oversized headings; prefer compact, data-first hierarchy.
- **Labels:** Use uppercase, 11–12px, tracking-wide for meta labels.

### Interaction Overrides
- **Tables:** Row hover, clickable rows with cursor pointer, visible focus rings.
- **Filters:** Inline chips + clear active state; avoid hidden filter affordances.
- **Loading:** Skeletons for charts/tables; spinners for small widgets.

---

## Recommendations
- Use “Data-Dense Dashboard” style (compact cards, grid alignment, consistent KPI tiles).
- Keep CTA usage minimal inside dashboards; reserve bright CTA for primary actions.
- Prefer subtle shadows and borders to separate cards in light/dark modes.
