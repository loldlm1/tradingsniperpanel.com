# Trading Sniper Panel

Rails 8 app that markets and manages our MQL5 EAs, starting with the Sniper Advanced Panel. Landing/auth UI comes from Cruip Neon; the authenticated dashboard uses Cruip Mosaic. Localization supports EN/ES with IP/Accept-Language detection and user overrides.

## Stack
- Ruby 3.4.5 / Rails 8.0.4, Postgres, importmap + propshaft.
- Tailwind (tailwindcss-rails) with Node CLI (`@tailwindcss/cli`) for builds; assets under `app/assets/templates/{neon,mosaic}`.
- Gems: devise, pay (Stripe), refer, maxminddb, rspec-rails, factory_bot_rails.

## Setup
1) Ensure asdf installs: `ruby 3.4.5`, `nodejs 24.6.0`.  
2) Copy env template: `cp .envrc.example .envrc && direnv allow` (or export vars manually).  
3) Install deps:
```
bundle install
npm install
```
4) Create DB once ready:
```
bin/rails db:create db:migrate
```
5) Run dev server + Tailwind watcher:
```
bin/dev
# or css-only: npm run dev:css
```

## Environment
- Postgres: `DB_HOST`, `DB_PORT`, `DB_USERNAME`, `DB_PASSWORD`, `DB_NAME`, `DB_NAME_TEST`.
- App/host: `APP_HOST`, `APP_HOST_PROTOCOL`, `RAILS_MASTER_KEY` (for credentials).
- Stripe (Pay): `STRIPE_SECRET_KEY`, `STRIPE_PUBLISHABLE_KEY`, `STRIPE_WEBHOOK_SECRET`, `STRIPE_PRICE_ID`.
- Referrals: `REFER_DEFAULT_DISCOUNT_PERCENT` (for downstream logic), query param `ref` handled by the refer gem.
- MaxMind GeoIP: place the DB at `maxmind/GeoLite2-City.mmdb` (or set `MAXMIND_DB_PATH`); `MAXMIND_LICENSE_KEY` for fetching the DB externally.
- Support email: `SUPPORT_EMAIL` (used by Devise/Pay mailers).

## Frontend notes
- Marketing/auth pages use Neon assets (`app/assets/templates/neon/...`), dashboard uses Mosaic (`app/assets/templates/mosaic/...`).
- Docs/manuals are exposed under `public/docs/sniper_advanced_panel/` (EN/ES Markdown + PDFs).
- Default layouts: marketing (`application.html.erb`) and dashboard (`dashboard.html.erb`); locale toggle is in the header.

## Testing
```
bundle exec rspec
```

## Code standards
- Prefer POROs/service objects for business logic, I18n for copy (EN/ES), and view partials/components for repeated UI.
- Keep Stripe/Pay actions idempotent; webhook endpoints (from Pay) live under `/pay`.
- Respect referral cookies (`ref`) before sign-up; locale detection falls back to user session override.
