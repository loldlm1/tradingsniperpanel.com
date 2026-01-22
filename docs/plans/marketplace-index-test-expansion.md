# Plan: Marketplace Index Test Expansion

## Goal
Expand automated coverage for the marketplace index redesign, focusing on search, filters, empty states, and section visibility.

## Definition of Done
- Service specs cover search, tag filtering, tab behavior, empty state logic, and trending card selection fallbacks.
- Request specs cover rendering of sections for courses/digital goods, hiding sections when empty, and locale-sensitive copy via I18n.
- External dependencies (Pay/Stripe) are stubbed or isolated to avoid network calls.

## Constraints
- Use request/system specs for full page flows and service specs for selection logic.
- Use I18n keys in specs instead of hardcoded UI copy.
- Keep factories lean; add traits only if needed.

## Steps
1. Identify critical edge cases not covered (no data, only courses, only EAs, query-only, tag-only, mixed filters).
2. Add service specs for `Marketplace::IndexPresenter` covering those cases and trending fallbacks.
3. Add request specs to validate rendered sections and empty state behavior across locales.
4. Run the relevant spec subset and adjust for stability/performance.

## Open Questions
- Should we include a spec for `Pay::Subscription`-driven trending plan, or stub it out entirely?
- Do we want to assert ordering of cards beyond presence/absence?

## Commands (discovery)
- None yet.
