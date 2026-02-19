# Plan: Marketplace Tabs and Dynamic Pagination

## Goal
Update marketplace index behavior so tabs no longer cap visible cards at 4, add dynamic pagination at 8 items per page, and introduce a separate `Featured` tab as the second tab (without making it the default).

## Definition of Done
- `tab=all` shows all matching entries (no 4-card cap).
- Non-`all` tabs show all matching entries for that type (no 4-card cap).
- Marketplace cards paginate client-side at 8 items per page using `app/javascript/paginated_lists.js` when section size exceeds 8.
- A `Featured` tab appears as the second tab, default tab remains `View All`.
- Tab/query/tag filters continue to work with the new tab and pagination UI.
- Specs covering marketplace presenter behavior pass.

## Constraints
- Keep existing dashboard marketplace layout/components intact.
- Preserve current purchase/usage-based sorting.
- Keep controller thin; implement behavior in presenter/view.
- Avoid breaking locale support (EN/ES tab labels and section labels).

## Steps
1. Extend `Marketplace::IndexPresenter` tab config/order and selection logic to include `featured` as a non-default tab.
2. Remove 4-card truncation from course and digital goods card builders.
3. Add presenter pagination helpers (page count metadata) for each rendered section.
4. Update marketplace index view to wire section containers/buttons to `paginated_lists.js` and only render controls when `> 8`.
5. Add/adjust presenter specs for featured tab selection and uncapped card lists.
6. Run targeted marketplace specs and record PASS/FAIL.

## Open Questions
- None (behavior confirmed by product direction in chat).

## Execution Log (PASS/FAIL)
- PASS: Created active plan doc `docs/plans/marketplace-tabs-featured-dynamic-pagination.md` before coding.
- PASS: Reviewed marketplace implementation points in `app/services/marketplace/index_presenter.rb`, `app/views/marketplace/index.html.erb`, and `app/javascript/paginated_lists.js`.
- PASS: Updated `app/services/marketplace/index_presenter.rb` to add `featured` tab (second), remove card caps, and expose section pagination metadata (`page_size`, `course_pages`, `digital_goods_pages`).
- PASS: Decision: `featured` tab renders both course and digital goods sections, and filters entries to purchase/usage-signaled products with a ranked fallback.
- PASS: Updated `app/views/marketplace/index.html.erb` to use `data-pagination-container`/`data-pagination-*` controls with 8-per-page dynamic pagination for course and digital goods sections.
- PASS: Updated `app/views/marketplace/cards/_course_card.html.erb` and `app/views/marketplace/cards/_digital_good_card.html.erb` to mark cards as `data-pagination-item`.
- PASS: Added locale labels for new tab in `config/locales/dashboard.en.yml` and `config/locales/dashboard.es.yml`.
- PASS: Extended coverage in `spec/services/marketplace/index_presenter_spec.rb` for featured tab behavior and uncapped card counts.
- PASS: Added index rendering coverage in `spec/requests/marketplace_spec.rb` for dynamic pagination controls when a section exceeds 8 cards.
- FAIL: `bundle exec rspec spec/services/marketplace/index_presenter_spec.rb spec/requests/marketplace_filters_spec.rb spec/requests/marketplace_spec.rb` (1 failure: featured tab course visibility expectation).
- PASS: Updated presenter `show_courses?` for `featured` tab and re-ran `bundle exec rspec spec/services/marketplace/index_presenter_spec.rb spec/requests/marketplace_filters_spec.rb spec/requests/marketplace_spec.rb` (34 examples, 0 failures).
- PASS: Re-ran `bundle exec rspec spec/services/marketplace/index_presenter_spec.rb spec/requests/marketplace_filters_spec.rb spec/requests/marketplace_spec.rb` after adding request coverage (35 examples, 0 failures).
