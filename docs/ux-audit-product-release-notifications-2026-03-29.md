# UX Audit: Product Release Notifications

**Date**: 2026-03-29  
**Target**: `http://127.0.0.1:3000`  
**Method**: `ux-audit` mindset + Playwright Firefox headless via [`script/product_release_visual_qa.mjs`](../script/product_release_visual_qa.mjs)  
**Artifacts**: `output/playwright/product-release-qa/summary.json`

## Verdict
Deploy-ready for this feature slice.

The follow-up fix sprint resolved both blocking issues from the first run:
- entitled owners now see the EA update item
- the mobile dropdown stays on-canvas at `375px`

## Resolved Findings

### Resolved: Owner users now see EA update items
- **Recheck status**: PASS
- **Verified with**:
  - `qa@example.com`
  - `1280px` light and dark
  - `768px` Spanish
- **Current result**:
  - add-on item present
  - EA update item present
  - course item present
- **Evidence**:
  - [`owner-en-desktop-light-dropdown.png`](/home/loldlm/rails_projects/tradingsniperpanel.com/output/playwright/product-release-qa/owner-en-desktop-light-dropdown.png)
  - [`summary.json`](/home/loldlm/rails_projects/tradingsniperpanel.com/output/playwright/product-release-qa/summary.json)

### Resolved: Mobile dropdown stays on-canvas at `375px`
- **Recheck status**: PASS
- **Verified with**:
  - `marketplace.seed.1@example.com`
  - `375px`
  - English
- **Current result**:
  - dropdown left edge renders at `x = 40`
  - full card remains visible
- **Evidence**:
  - [`addon-only-en-mobile-dropdown.png`](/home/loldlm/rails_projects/tradingsniperpanel.com/output/playwright/product-release-qa/addon-only-en-mobile-dropdown.png)
  - [`summary.json`](/home/loldlm/rails_projects/tradingsniperpanel.com/output/playwright/product-release-qa/summary.json)

## Remaining Notes

### Low: Sign-in page emits an unused preload warning
- **Severity**: Low
- **Scope**: not specific to the release notification feature
- **Observed with**:
  - Firefox headless sign-in flow
- **Evidence**:
  - [`summary.json`](/home/loldlm/rails_projects/tradingsniperpanel.com/output/playwright/product-release-qa/summary.json)

## Passed Checks
- Add-on visibility rule worked for a signed-in non-owner user.
- Course item visibility worked for the owner user in both EN and ES.
- EA update visibility worked for the entitled owner user in both EN and ES.
- Add-on click-through navigated to the marketplace detail page correctly.
- EA click-through navigated to the EA detail page correctly.
- Dismiss removed the unread dot and stayed dismissed after reload.
- Desktop dark mode did not introduce clipping or overflow in the notification card.
- Mobile `375px` layout remained on-canvas after the dropdown alignment fix.

## Click Efficiency
- Bell discovery: `1` click from dashboard load to open the release.
- Dismiss flow: `2` interactions after noticing the bell.
- Item click-through: works for the add-on and course paths tested.

## Trust And Comprehension Notes
- The bell affordance is familiar and low-friction.
- The grouped copy reads clearly in both EN and ES when the items render.
- The grouped three-item state now reads clearly and matches the release summary count.
- The mobile card now feels anchored to the trigger instead of drifting off-screen.

## Would I Come Back?
Yes. This feature is now in a state I would ship for the scoped V1 behavior.

## Recommended Next Step
1. Optionally remove or investigate the low-severity sign-in preload warning separately.
2. Keep [`script/product_release_visual_qa.mjs`](/home/loldlm/rails_projects/tradingsniperpanel.com/script/product_release_visual_qa.mjs) as the regression runner for future notification changes.
