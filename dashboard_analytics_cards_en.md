# Dashboard Analytics - card plan for trader

## Objective
Define useful information for the end trader in each analytics dashboard card and order by priority (top -> bottom).

## Base assumptions
- Audience: end trader.
- Default window: last 30 days, compared vs previous 30 days.
- Shortcuts: 7 and 90 days.
- Time zone: `users.time_zone` if present; otherwise UTC.
- Currency: `pay_charges.currency` or user preference.
- No-data state: show "Not enough data" and hide comparisons.
- Balance: 60% Expert Advisor/trading, 40% courses.
- Courses: metrics only for the current user (not global).

## Priority and suggested order (top -> bottom)
1. Daily performance (Line chart - Analytics) [Expert Advisor]
2. Expert Advisors active now (Line chart - Active Users Right Now) [Expert Advisor]
3. Expert Advisor results (Stacked bar - Acquisition Channels) [Expert Advisor]
4. Top courses by progress (Horizontal bar - Audience Overview) [Courses]
5. Top Expert Advisors by profit (Report card - Top Channels) [Expert Advisor]
6. Latest lessons watched (Report card - Top Pages) [Courses]
7. Licenses expiring soon (Report card - Top Countries) [Expert Advisor]
8. Course status (Doughnut - Sessions By Device) [Courses]
9. Study time by category (Doughnut - Visit By Age Category) [Courses]
10. Expert Advisor type in use (Polar - Sessions By Gender) [Expert Advisor]

## Visual ordering
- The current order in `dashboard_analytics.html` already matches this priority.
- If reordered, keep the sequence listed above.

## Cards (details)

### 1) Daily performance [Expert Advisor]
HTML name (comment): <!-- Line chart (Analytics) -->
Visible title: Daily performance
Type: Line chart
Canvas id: analytics-card-01
Legend id: none
Current content / UI copy:
- Subtitle: Net Profit & Loss and 30-day trend.
- KPIs: 30-day Profit & Loss, Cumulative Profit & Loss, Positive days, Max drawdown.
- Tooltip: Net Profit & Loss = sum of daily results; Max drawdown = largest drop from the peak.
Metrics / Formula:
- Daily Profit & Loss (PnL) = sum(`broker_account_daily_results.result_value`) grouped by local day.
- 30-day Profit & Loss = sum(Daily Profit & Loss) within the 30-day window.
- Cumulative Profit & Loss = cumulative sum of Daily Profit & Loss.
- Positive days (%) = count(Daily Profit & Loss > 0) / count(days with data).
- Max drawdown = max(peak_cumulative - current_cumulative) within the window.
Sources: `broker_account_daily_results` -> `broker_accounts` -> `licenses` -> `expert_advisors`.
Rules / Notes:
- Filter by `licenses.user_id`.
- Consolidate multiple accounts per license.
- Allow real/demo account filter.
CTA: View performance details.
Empty state: Not enough data.

### 2) Expert Advisors active now [Expert Advisor]
HTML name (comment): <!--  Line chart (Active Users Right Now) -->
Visible title: Expert Advisors active now
Type: Line chart
Canvas id: analytics-card-02
Legend id: none
Current content / UI copy:
- Subtitle: Activity in the last 30 minutes.
- KPIs: Active licenses (30m), Active accounts today.
- Table: Expert Advisor | Active accounts.
Metrics / Formula:
- Active licenses (30m) = count(distinct `licenses.id`) with `status` in (active, trial) and `last_synced_at` >= now - 30m.
- Active accounts today = count(distinct `broker_accounts.id`) with results in the last 24h.
- Table = group by `expert_advisors.name` with count of active accounts in 24h.
Sources: `licenses.last_synced_at`, `broker_accounts`, `expert_advisors`.
Rules / Notes:
- If `last_synced_at` is missing, use accounts with results recorded today as proxy.
CTA: View activity.
Empty state: No recent activity.

### 3) Expert Advisor results [Expert Advisor]
HTML name (comment): <!-- Stacked bar chart (Acquisition Channels) -->
Visible title: Expert Advisor results
Type: Stacked bar chart
Canvas id: analytics-card-03
Legend id: analytics-card-03-legend
Current content / UI copy:
- Subtitle: 30-day Profit & Loss by Expert Advisor and account type.
- Legend: Real, Demo.
Metrics / Formula:
- 30-day Profit & Loss by Expert Advisor and account = sum(result_value) in 30 days, grouped by Expert Advisor and `account_type`.
- Total per Expert Advisor = sum(Real + Demo Profit & Loss).
Sources: `broker_account_daily_results`, `broker_accounts.account_type`, `expert_advisors`.
Rules / Notes:
- Show top 5-7 Expert Advisors by Profit & Loss and one "Other" bucket.
CTA: none
Empty state: No results in the period.

### 4) Top courses by progress [Courses]
HTML name (comment): <!-- Horizontal bar chart (Audience Overview) -->
Visible title: Top courses by progress
Type: Horizontal bar chart
Canvas id: analytics-card-04
Legend id: analytics-card-04-legend
Current content / UI copy:
- Subtitle: Courses in progress.
- Axis/tooltip: Progress (%).
Metrics / Formula:
- Progress per course = `course_enrollments.progress_percent` (0..100).
Sources: `course_enrollments` -> `courses`.
Rules / Notes:
- Filter by `course_enrollments.user_id`.
- Show top 6-8 courses in progress.
- Sort by progress desc and hide completed if there are many.
CTA: none
Empty state: No courses in progress.

### 5) Top Expert Advisors by profit [Expert Advisor]
HTML name (comment): <!-- Report card (Top Channels) -->
Visible title: Top Expert Advisors by profit
Type: Report card
Canvas id: none
Legend id: none
Current content / UI copy:
- Subtitle: 30-day net Profit & Loss.
- Table: Expert Advisor | 30-day Profit & Loss.
Metrics / Formula:
- 30-day Profit & Loss per Expert Advisor = sum(result_value) in 30 days, grouped by Expert Advisor.
- Change = (current 30-day Profit & Loss - previous 30-day Profit & Loss) / abs(previous 30-day Profit & Loss) if previous != 0.
Sources: `broker_account_daily_results`, `expert_advisors`.
Rules / Notes:
- Show change vs previous period if data exists.
CTA: View Expert Advisor details.
Empty state: No Profit & Loss in the period.

### 6) Latest lessons watched [Courses]
HTML name (comment): <!-- Report card (Top Pages) -->
Visible title: Latest lessons watched
Type: Report card
Canvas id: none
Legend id: none
Current content / UI copy:
- Subtitle: Pick up where you left off.
- Table: Lesson | Progress.
Metrics / Formula:
- Order = `course_lesson_progresses.last_watched_at` desc.
- Progress % = min(100, progress_seconds / duration_seconds * 100) if `duration_seconds` > 0.
- Progress min = progress_seconds / 60 if `duration_seconds` is not available.
Sources: `course_lesson_progresses` -> `course_lessons` -> `courses`.
Rules / Notes:
- Filter by `course_lesson_progresses.user_id`.
- If no lessons, show CTA "View courses".
CTA: View courses.
Empty state: No lessons watched yet.

### 7) Licenses expiring soon [Expert Advisor]
HTML name (comment): <!-- Report card (Top Countries) -->
Visible title: Licenses expiring soon
Type: Report card
Canvas id: none
Legend id: none
Current content / UI copy:
- Subtitle: Avoid interruptions.
- Table: Expert Advisor | Expires in.
Metrics / Formula:
- Expiration date = coalesce(`trial_ends_at`, `expires_at`).
- Days remaining = date(expiration_date) - today.
Sources: `licenses.expires_at`, `licenses.trial_ends_at`, `expert_advisors`.
Rules / Notes:
- Filter by `licenses.user_id`.
- Sort ascending by days remaining.
CTA: Renew license.
Empty state: No upcoming expirations.

### 8) Course status [Courses]
HTML name (comment): <!-- Doughnut chart (Sessions By Device) -->
Visible title: Course status
Type: Doughnut chart
Canvas id: analytics-card-08
Legend id: analytics-card-08-legend
Current content / UI copy:
- Subtitle: Course balance.
- Legend: Not started, In progress, Completed.
Metrics / Formula:
- Not started = `progress_percent` = 0 and `completed_at` is null.
- In progress = `progress_percent` between 1 and 99 and `completed_at` is null.
- Completed = `completed_at` not null or `progress_percent` >= 100.
Sources: `course_enrollments`.
Rules / Notes:
- Count only courses enrolled by the user.
CTA: none
Empty state: No enrolled courses.

### 9) Study time by category [Courses]
HTML name (comment): <!-- Doughnut chart (Visit By Age Category) -->
Visible title: Study time by category
Type: Doughnut chart
Canvas id: analytics-card-09
Legend id: analytics-card-09-legend
Current content / UI copy:
- Subtitle: 30-day minutes distribution.
- Legend: course categories.
Metrics / Formula:
- 30-day minutes by category = sum(progress_seconds) / 60, grouped by `courses.category`.
Sources: `course_lesson_progresses.progress_seconds` -> `course_lessons` -> `course_modules` -> `courses`.
Rules / Notes:
- Filter by `course_lesson_progresses.user_id`.
- Group small categories into "Other".
CTA: none
Empty state: No recent study time.

### 10) Expert Advisor type in use [Expert Advisor]
HTML name (comment): <!-- Polar chart (Sessions By Gender) -->
Visible title: Expert Advisor type in use
Type: Polar chart
Canvas id: analytics-card-10
Legend id: analytics-card-10-legend
Current content / UI copy:
- Subtitle: Robots vs tools in use.
- Legend: Expert Advisor robot, Expert Advisor tool.
Metrics / Formula:
- Distribution by type = count(distinct `licenses.id`) by `expert_advisors.ea_type`.
Sources: `expert_advisors.ea_type`, `licenses.status`.
Rules / Notes:
- Count only `active` and `trial`.
CTA: none
Empty state: No active licenses.
