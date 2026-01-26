# Goal
- Produce a Stripe-aligned policy and disclosure plan for a trading-education SaaS + digital-goods platform, ready for website verification and scalable to multi-country rollout.

# Definition of Done
- Inventory of current policy pages, URLs, pricing/checkout flows, and support channels.
- Business-model classification (single-merchant SaaS vs software platform with BYO-Stripe vs marketplace/Connect) with Stripe product fit.
- Gap analysis against Stripe website checklist + restricted/reviewed categories.
- Draft policy map: ToS, Privacy, Refund/Cancellation, Delivery/Access, Support/Contact, Creator Terms, Acceptable Use, Marketing/Claims guidelines, and any required risk disclaimers.
- Localization scope decided (EN/ES) and copy outline ready for implementation.
- Verification checklist for Stripe (site + business info) and legal review handoff prepared.

# Constraints
- Not legal advice; final copy must be reviewed by counsel.
- Must follow Stripe website requirements and restricted/reviewed business rules.
- No financial advice or earnings promises; marketing claims must be supportable.
- Keep policies consistent with actual product behavior (billing, access, refunds, creator payouts).

# Current Inputs
- Policies located at `legal#terms` and `legal#privacy`.
- Business model: white-label SaaS sold to creators/influencers; creators use their own Stripe accounts (not our Connect account). Revenue share via custom invoices/manual agreements; service shutoff if unpaid.
- Billing: subscriptions, one-time, discount codes; no refunds; users can cancel subscriptions anytime. Checkout acknowledgement required.
- No signals/copy-trading/account management features.
- Entity: each client must have their own Stripe-eligible entity (US LLC or a Stripe-supported country). Our company is a software provider based in Venezuela.
- No public earnings/performance claims; users only see their own private stats.
- Testimonials focus on tool usage, not profits.
- Support contact: admin email (Discord/Telegram planned later); each client uses their own support email via `SUPPORT_EMAIL`.
- End customers pay creators directly (creator is MoR).
- Checkout uses Stripe Checkout via the Pay gem for end-customer purchases inside the software, created with each client’s Stripe secret key (BYO-Stripe).
- Clients can manage their instance via ActiveAdmin.
- Must audit both landing templates (`neon` + `fintech`), as clients choose.
- Custom domains per client; legal pages must render on each custom domain.
- Stripe keys are provided per-tenant via env vars; only the client has access.
- Legal pages should show the client’s company name/address as the merchant.
- Client sites are single-merchant only (no third-party sellers).
- Plan includes visual audit of rendered pages and adding brand setup env vars for client company metadata.

# Initial Site Findings (local review)
- Routes: `terms` -> `legal#terms`, `privacy` -> `legal#privacy`, `terms_acceptance` flow exists. (`config/routes.rb`)
- Views: legal pages render `app/views/legal/_document.html.erb` and use I18n sections from `config/locales/en.yml` + `config/locales/es.yml`.
- Terms already include: Stripe processor mention, no refunds (except where required by law), trading risk disclaimer, no financial advice language.
- Landing template system: default landing template is `neon` and views live under `app/views/templates/neon`. (`app/services/marketing/landing_template.rb`)
-
# Visual Audit Findings (local render)
- `neon` landing: footer contains only Terms + Privacy links; no contact methods shown. Support email appears nowhere on the page.
- `fintech` landing: includes a “Talk to support” mailto CTA using `support_email`, but footer still only shows Terms + Privacy.
- `/terms` and `/privacy` pages render, but `%{support_email}` is not interpolated (shows literal placeholder), so contact email is missing.
- Marketing copy includes “signals” references (fintech sections + locales) that may conflict with your “no signals/copy-trading” stance.

# Decisions (in progress)
- Add refund acknowledgement at checkout (plans + marketplace) with a server-side guard.
- Add business info + contact blocks to Terms/Privacy using per-tenant branding fields.
- Replace “signals” marketing copy with “playbooks/workflows” language in EN/ES.

# Stripe Policy Notes (research)
- Website checklist requires multiple, direct contact methods (email + phone/live chat/etc) and clear fulfillment policies including refund, delivery, and cancellation.
- “Content creation platforms” that enable third-party creators to sell digital goods are restricted and may require additional due diligence.
- LATAM account availability currently appears limited to certain countries (e.g., Brazil and Mexico). Peru is not listed at time of review; re-check before launch.

# Steps
1) Collect current policies, URLs, pricing, billing model (one-time vs subscription), refund behavior, support contacts, and onboarding flow for creators.
2) Review Stripe requirements (website checklist + restricted business categories + global availability) and map them to current pages.
3) Decide the platform model (single merchant vs BYO-Stripe SaaS vs marketplace/Connect) and required due diligence for creators.
4) Draft policy updates + disclosure matrix per product line (EAs, scripts, courses, indicators, platform tools) including “no refunds” policy language aligned with local consumer laws.
5) Prepare implementation plan for Rails (I18n keys, page routes, footer links, content ownership).
6) Add brand setup env variables (merchant name, address, support channels, jurisdiction) and wire them into legal/marketing pages.
7) Visual audit: run the app locally, verify both landing templates (neon + fintech), legal pages, checkout entry points, and footer links.
8) Run verification readiness review and schedule legal/compliance review.

# Open Questions
- Revenue share mechanics: How do you collect your share if creators use their own Stripe accounts (manual invoicing, separate SaaS fee, or planned Connect application fees)?
- Merchant of record: Are end customers buying from the creators (creator as MoR) or from your company?
- Pay/Checkout scope: Is Pay + Stripe Checkout used only for creator subscriptions, or also for end-customer purchases? If end-customer purchases are on-platform, how do you connect to creator Stripe accounts without Connect?
- Are you charging creators a SaaS subscription (B2B) in addition to end-customer sales for their products?
- What are the full URLs for `/terms` and `/privacy` in production (do they live at root or under locale)?
- What support channels should be public (email/phone/chat), and what business address should appear on-site?
- Which LATAM countries are in scope for creator onboarding (merchant accounts), and do you have local entities for any of them?
- Do you require users to acknowledge “no refunds” at checkout, and do you offer trials or pro-rated billing?
- Are there any public marketing pages with testimonials or affiliate promotions that need disclosure language?
- Entity clarification: Are you operating through a US LLC or another Stripe-eligible entity, or none yet? This affects whose site is verified and who appears as the merchant.
- Custom domains: Do legal pages (`/terms`, `/privacy`) render under each client’s custom domain, or only under your primary domain?
- Stripe key management: How are client Stripe API keys collected/stored/rotated (env vars per tenant, encrypted DB fields, vault)?
- End-customer checkout: Is Stripe Checkout created with each client’s secret key, or do you plan to implement Stripe Connect later?
- Legal ownership: Do you want the legal pages to show the client’s company name/address as the merchant, or your company as the software provider?
- Platform attribution: Should client legal pages mention the software provider brand at all, and if so, where?
- Do clients sell only their own products, or can they host third-party sellers on their domain (multi-vendor)? This impacts Stripe “platform” classification.
- Brand env scope: Which merchant fields should be configurable per client (legal name, trade name, address, phone, support channels, jurisdiction/tax ID)?
- Are you okay adding a “support channels” section to the footer (email + Discord/Telegram/chat) to satisfy Stripe’s contact-method expectations?

# Execution Log
- PASS: `rg -n "legal|terms|privacy|refund|policy" config/routes.rb`
- PASS: `sed -n '1,140p' config/routes.rb`
- PASS: `rg -n "legal#|terms|privacy" app/views app/controllers`
- PASS: `ls app/views/legal`
- PASS: `sed -n '1,200p' app/views/legal/terms.html.erb`
- PASS: `sed -n '1,200p' app/views/legal/privacy.html.erb`
- PASS: `sed -n '1,200p' app/views/legal/_document.html.erb`
- PASS: `rg -n "legal" config/locales/en.yml config/locales/es.yml`
- PASS: `sed -n '150,420p' config/locales/en.yml`
- PASS: `rg -n "support_email" app/helpers app/controllers app/views config`
- PASS: `rg -n "class PagesController|pages#home" app/controllers app/views`
- PASS: `sed -n '1,200p' app/controllers/pages_controller.rb`
- PASS: `rg -n "landing|pages/home|home" app/views/pages app/views`
- PASS: `rg -n "view_path|prepend_view_path|append_view_path|template" app/controllers app/helpers app/views config`
- PASS: `sed -n '1,140p' app/controllers/application_controller.rb`
- PASS: `rg -n "LandingTemplate" app lib`
- PASS: `sed -n '1,200p' app/services/marketing/landing_template.rb`
- PASS: `bin/rails server -p 3000 -e development > tmp/rails-server.log 2>&1 & echo $!`
- PASS: `curl -H "Accept: text/html" -A "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" -s -o /tmp/home.html -w "%{http_code}\\n" http://localhost:3000/`
- PASS: `sed -n '540,590p' /tmp/home.html`
- PASS: `curl -H "Accept: text/html" -A "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" -s -o /tmp/terms.html -w "%{http_code}\\n" http://localhost:3000/terms`
- PASS: `curl -H "Accept: text/html" -A "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" -s -o /tmp/privacy.html -w "%{http_code}\\n" http://localhost:3000/privacy`
- PASS: `kill 83526`
- PASS: `LANDING_TEMPLATE=fintech bin/rails server -p 3000 -e development > tmp/rails-server.log 2>&1 & echo $!`
- PASS: `curl -H "Accept: text/html" -A "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" -s -o /tmp/home_fintech.html -w "%{http_code}\\n" http://localhost:3000/`
- PASS: `rg -n "footer|Terms|Privacy|Support|contact|support" /tmp/home_fintech.html`
- PASS: `kill 84101`
- FAIL: `mcp__playwright__browser_install` (requires sudo to install Chrome)
- PASS: `rg -n "señal|señales|signals" config/locales/es.yml`
- PASS: `sed -n '35,80p' config/locales/es.yml`
- PASS: `sed -n '430,520p' config/locales/es.yml`
- PASS: `sed -n '520,620p' config/locales/es.yml`
- PASS: `sed -n '620,700p' config/locales/es.yml`
- PASS: `rg -n "footer:" -n config/locales/es.yml | head`
- PASS: `sed -n '150,200p' config/locales/es.yml`
- PASS: `rg -n "terms:" config/locales/en.yml`
- PASS: `sed -n '190,260p' config/locales/en.yml`
- PASS: `rg -n "signals|signal" config/locales/en.yml`
- PASS: `rg -n "signals" config/locales/en.yml`
- PASS: `rg -n "fintech:" -n config/locales/en.yml`
- PASS: `sed -n '458,560p' config/locales/en.yml`
- PASS: `sed -n '560,660p' config/locales/en.yml`
- PASS: `rg -n "legal:" -n config/locales/es.yml`
- PASS: `sed -n '200,320p' config/locales/es.yml`
- PASS: `rg -n "checkout" app/views/dashboards app/views/marketplace`
- PASS: `sed -n '120,220p' app/views/marketplace/show.html.erb`
- PASS: `sed -n '120,220p' app/views/dashboards/plans.html.erb`
- PASS: `rg -n "def checkout" app/controllers -S`
- PASS: `sed -n '1,120p' app/controllers/dashboards_controller.rb`
- PASS: `sed -n '1,140p' app/controllers/marketplace_controller.rb`
- PASS: `sed -n '1,160p' app/controllers/application_controller.rb`
- PASS: `rg -n "cart-submit" app/javascript`
- PASS: `sed -n '1,200p' app/javascript/marketplace_show.js`
- PASS: `rg -n "checkout" config/locales/en.yml`
- PASS: `rg -n "brand_display_name|brand_address" app/helpers/application_helper.rb`
- PASS: `sed -n '1,120p' app/helpers/application_helper.rb`
- PASS: `sed -n '1,120p' app/javascript/application.js`
- PASS: `sed -n '1,120p' config/importmap.rb`
- PASS: `rg -n "refund_acknowledgement" -S app config`
