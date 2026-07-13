# Trading Sniper Panel

Rails 8 SaaS app that markets and manages MQL5 EAs with subscriptions and licensing. Landing/auth UI comes from Cruip templates (Neon by default via `LANDING_TEMPLATE`); the authenticated dashboard uses Cruip Mosaic. Localization supports EN/ES with IP/Accept-Language detection and user overrides.

## Stack
- Ruby 3.4.5 / Rails 8.0.4, Postgres, importmap + propshaft.
- Tailwind (tailwindcss-rails) with Node CLI (`@tailwindcss/cli`) for builds; assets under `app/assets/templates/{neon,mosaic}`.
- Gems: devise, pay (Stripe), refer, maxminddb, rspec-rails, factory_bot_rails, sidekiq.
- Domain models: ExpertAdvisor records (ea_robot/ea_tool) with documents JSON and allowed subscription tiers; UserExpertAdvisors join grants per user (soft-deletable on downgrade).

## Local setup
1) Install tool versions with asdf:
```
asdf install
```
2) Copy env template: `cp .envrc.example .envrc && direnv allow` (or export vars manually). Ensure `RAILS_MASTER_KEY` matches `config/master.key` or unset it so Rails reads that file.
3) Install deps:
```
bundle install
npm install
```
4) Create DB once ready:
```
bin/rails db:create db:migrate
# optional sample data
bin/rails db:seed
```
5) Run dev server + Tailwind watcher:
```
bin/dev
# or css-only: npm run dev:css
```

## Partner payout setup and QA
- Referral discounts are injected automatically before Stripe Checkout is created when the customer has an attributed partner referrer. The app applies the referral discount first in `app/services/billing/apply_referral_discount.rb`, and dashboard promo codes only apply when no referral discount has already been attached.
- Configure partner payout notification recipients with a comma-separated env var:
```
export PARTNER_PAYOUT_REQUEST_RECIPIENTS="ops@example.com, finance@example.com, owner@example.com"
```
- The payout request mailer uses these templates:
  - `app/views/partner_payout_requests_mailer/request_notification.html.erb`
  - `app/views/partner_payout_requests_mailer/request_notification.text.erb`
- Full QA seeds in development/staging create these partner accounts with password `Password123!`:
  - `qa.partner@example.com`: pending/request-history dashboard state
  - `qa.partner.eligible@example.com`: click-ready payout dashboard state with requestable balance >= `$200`
- If you only want the partner QA accounts without a full reseed, run:
```
bin/rails runner 'load Rails.root.join("db/seeds/shared.rb"); qa_users = Seeds::QaUsers.seed!; Seeds::Partners.seed_qa!(partner: qa_users[:partner]); Seeds::Partners.seed_eligible_qa!(partner: qa_users[:eligible_partner])'
```

## Support chat setup (`tawk.to`, production only)
- The current v1 support bubble uses `tawk.to` as a site-wide embedded widget in `production`.
- This does **not** require a Rails route like `/chat` for v1. The widget is intended to load across approved pages in the existing app layout.
- Admins receive support messages through the `tawk.to` inbox and the official mobile app.
- The widget is rendered from:
  - `app/views/layouts/application.html.erb` for public + auth pages
  - `app/views/layouts/dashboard.html.erb` for authenticated dashboard pages
- The helper gate is in `app/helpers/application_helper.rb` and will only render the widget when all of these are true:
  - Rails is running in `production`
  - `SUPPORT_CHAT_EMBED_PROVIDER=tawk_to`
  - `TAWKTO_PROPERTY_ID` is present
  - `TAWKTO_WIDGET_ID` is present
- App-side env vars for the widget:
```
export SUPPORT_CHAT_EMBED_PROVIDER=tawk_to
export TAWKTO_PROPERTY_ID=your_property_id
export TAWKTO_WIDGET_ID=your_widget_id
# Optional but recommended if you want the app to securely identify signed-in users
export TAWKTO_API_KEY=your_tawkto_secure_mode_key
```

### Env reference
- `SUPPORT_CHAT_URL`
  - Leave blank for the current `tawk.to` embed setup.
  - This is for a generic support link and is not used by the embedded widget path.
- `SUPPORT_CHAT_EMBED_PROVIDER`
  - Required for the widget.
  - Must be exactly `tawk_to` or the helper will not render the embed script.
- `TAWKTO_PROPERTY_ID`
  - Required for the widget.
  - This is not a custom value; it comes from your `tawk.to` property and is used as the first path segment in the embed URL.
- `TAWKTO_WIDGET_ID`
  - Required for the widget.
  - This is the widget identifier from your `tawk.to` dashboard and is used as the second path segment in the embed URL.
- `TAWKTO_API_KEY`
  - Optional.
  - Only needed if you want secure signed-in visitor identification. Leaving it blank should still show the widget normally.

### Where to get the `tawk.to` IDs
1) In `tawk.to`, go to `Administration -> Chat Widget` and copy the full widget code.
2) Find the script URL that looks like:
```
https://embed.tawk.to/PROPERTY_ID/WIDGET_ID
```
3) Use:
   - `TAWKTO_PROPERTY_ID=PROPERTY_ID`
   - `TAWKTO_WIDGET_ID=WIDGET_ID`

### Quick troubleshooting
- If nothing appears after deploy, first check that the app is really running in `production`. The widget is intentionally disabled outside production.
- Confirm the exact env values loaded by the Rails process:
```
bin/rails runner 'pp({ env: Rails.env, provider: Rails.configuration.x.branding.support_chat_embed_provider, property: Rails.configuration.x.branding.tawkto_property_id, widget: Rails.configuration.x.branding.tawkto_widget_id, secure_mode: Rails.configuration.x.branding.tawkto_api_key.present? })'
```
- If `property` or `widget` prints `nil` or an empty string, the deploy environment did not load the values correctly.
- If you only configured `TAWKTO_WIDGET_ID`, the widget will not load. The app needs both `TAWKTO_PROPERTY_ID` and `TAWKTO_WIDGET_ID`.
- After changing env vars in production, restart the app processes so Rails reloads the branding initializer.

### Initial provider setup
1) Create or sign in to your `tawk.to` account.
2) Create/select the property for `tradingsniperpanel.com`.
3) In the `tawk.to` dashboard, go to `Administration -> Chat Widget`.
4) Copy the widget JavaScript snippet or note the property/widget identifiers from it. The Rails app uses env-backed widget identifiers in production.
5) Invite 1-2 admins:
   - Dashboard path: `Administration -> Property Members -> Invite Member`
   - Use `Admin` for full access or `Agent` for reply-only staff.
6) Ask each invited admin to accept the invite from email and log in once before testing mobile notifications.

### Android/iOS agent setup
1) Install the official `tawk.to` mobile app on each admin phone.
2) Sign in with the same email used for the property invite.
3) Accept the property invitation if the app/dashboard prompts for it.
4) Open the property in the mobile app and confirm:
   - personal status is `Online` or `Away`
   - property/site status is enabled
   - Do Not Disturb inside the app is off unless intentionally used

### Android notification checklist
1) In the Android app, open `You -> App Settings -> Configure Alerts`.
2) Enable the notification types you want, then choose sound/vibration behavior.
3) Make sure your agent status is `Online` or `Away` or you may miss live chats.
4) On the Android device itself:
   - allow notifications for the `tawk.to` app
   - remove `tawk.to` from battery optimization if notifications are delayed
   - allow auto-start / background activity on vendors that restrict background apps
5) If chats are not coming through, re-open the app once after changing notification settings and test again from the live site.

### iPhone / iPad notification checklist
1) In the iOS app, open `You -> App Settings -> Notifications and Sounds`.
2) Enable the notification types you want and confirm in-app `Do Not Disturb` is off.
3) In iOS Settings, open the `tawk.to` app notification settings and enable `Allow Notifications`.
4) If alerts still do not appear, enable banners/sounds for the app and re-open `tawk.to`.

### Quick production QA
1) Confirm the widget appears on the approved production pages.
2) Send a test message from a private/incognito browser window.
3) Verify:
   - the conversation reaches the `tawk.to` dashboard
   - at least one admin phone receives the notification
   - the admin can reply from the mobile app

### Official references
- Widget install: https://help.tawk.to/article/adding-a-widget-to-your-website
- Invite/manage agents: https://help.tawk.to/article/how-to-invite-and-manage-agents
- Android widget code access: https://help.tawk.to/article/where-to-find-your-widget-code-on-android
- Android notifications: https://help.tawk.to/article/enabling-notifications-on-android
- Android notification troubleshooting: https://help.tawk.to/article/not-receiving-chat-notifications
- iOS notifications: https://help.tawk.to/article/how-to-manage-sounds-and-notifications-in-ios
- iOS notification troubleshooting: https://help.tawk.to/article/why-am-i-not-getting-notifications-on-ios

## Product release notifications (production admin flow)
- V1 release notifications are published from production ActiveAdmin after product changes are live.
- Update the qualifying products first:
  - EA downloadable file or active bundle changed
  - new course became published
- Then open `Admin -> Product Releases` and click `Publish Product Release`.
- The app will diff the current tracked catalog against the last published snapshot.
- If qualifying changes are found, one grouped release batch is created for dashboard users.
- If nothing qualifies, ActiveAdmin returns a clean no-op notice and no user-facing release is created.

## Pandora subscription operations

- Pandora Box EA is the only active purchasable product. The canonical plans are `$79.00/month` (`pandora_pro_monthly`) and `$616.20/year` (`pandora_pro_annual`). The annual amount is the integer-cent calculation `7900 * 12 * 65 / 100`, a 35% discount from twelve monthly periods.
- Historical plans, Stripe price mappings, marketplace purchases, charges, and invoices remain stored for audit, but retired products cannot start a new checkout or grant access.
- Existing renewable Stripe subscriptions keep their current price and quantity through `current_period_end`. Seed reconciliation schedules the interval-matched Pandora price for the next period without immediate swaps or proration; subscriptions already ending are not renewed.
- `Admin -> Subscription Audits` shows the effective access source, status, period, products, promotions/discounts, gross/refunds/net totals by currency, invoice history, manual grants, license status, token version, and safe processor references.
- `Admin -> Manual Subscriptions -> New` finds users by email and grants Pandora access by plan and days without loading the full user table. A grant starts after the later of now or the user's current manual end. Complimentary and pending grants contribute `$0` settled revenue; a later paid Stripe subscription supersedes remaining manual access. Active or future manual grants can be revoked immediately while preserving their original period and an admin audit event.
- Admins and master admins can rotate one user's active/trial subscription license tokens. Only master admins can rotate all active/trial tokens. Rotation is atomic, idempotently audited, and immediately invalidates prior keys on every licensing endpoint.
- User roles never grant product access. Admin roles authorize administration only; product access still requires a current Stripe subscription or active manual grant.
- Never rotate tokens from a seed, migration, deploy hook, or role callback. Compile, distribute, and confirm the Pandora client with v2 token parsing before any rotation.

The production sequence, staging rehearsal, post-deploy checks, schedule rollback limits, manual grant procedure, and token-rotation gate are documented in `docs/pandora_subscription_rollout_runbook.md`.

## Server setup (Ubuntu 22.04, staging + production on the same VPS)

### Recommended: setup scripts
1) Add your server SSH key to GitHub for `git@github.com:loldlm1/tradingsniperpanel.com.git`.
2) Ensure the host has the minimal bootstrap tools needed for repo sync before the setup script installs the full package set:
```
sudo apt update
sudo apt install -y git openssh-client
```
3) Copy the deploy scripts somewhere outside the repo. Any readable external path is supported; use a root-writable location if you want self-updates to replace the local copies in place:
```
sudo install -d /opt/tradingsniperpanel-deploy
# Copy these files into /opt/tradingsniperpanel-deploy: setup_common.sh, setup_production.sh, setup_staging.sh
```
Optional: add execute bits if you also want direct invocation, but the canonical path is still `sudo bash ...`.
4) Run production setup from the external script (it will sync the repo first and self-update the local scripts if needed):
```
sudo bash /opt/tradingsniperpanel-deploy/setup_production.sh
```
If SSL files are not installed yet, the script will stop after setup; install certs and rerun.
If your SSH key has a passphrase, load it into ssh-agent before running the script (for example: `eval "$(ssh-agent -s)" && ssh-add ~/.ssh/id_ed25519`). The scripts try to detect your agent; if they still complain, run with `sudo -E` to preserve `SSH_AUTH_SOCK`.
On first run it will create `/home/$USER/tradingsniperpanel.com/.envrc` and exit. Fill it with production values (`APP_HOST=tradingsniperpanel.com`, `APP_HOST_PROTOCOL=https`, `PORT=48501`, `REDIS_URL=redis://localhost:6379/0`, `DB_HOST`, `DB_PORT`, `DB_USERNAME`, `DB_PASSWORD`, and all `DB_NAME_PRODUCTION*` values), then rerun the same command.
GitHub SSH now defaults to `ssh.github.com:443` for these setup scripts. Only force port 22 if your network path explicitly allows it:
```
GITHUB_SSH_PORT=22 sudo bash /opt/tradingsniperpanel-deploy/setup_production.sh
```
If an older external copy still hangs on `github.com:22`, recopy the latest `setup_common.sh`, `setup_production.sh`, and `setup_staging.sh` from this repo and rerun.
5) Run staging setup:
```
sudo bash /opt/tradingsniperpanel-deploy/setup_staging.sh
```
On first run, it will create `/home/$USER/tradingsniperpanel.com-staging/.envrc` and exit. Fill it with staging values (`APP_HOST=<staging-host>`, `APP_HOST_PROTOCOL=http`, `PORT=48502`, `REDIS_URL=redis://localhost:6379/1`, `DB_HOST`, `DB_PORT`, `DB_USERNAME`, `DB_PASSWORD`, `DB_NAME_STAGING*`, `STAGING_ALLOWLIST=<your_client_ip>`), then rerun.
If `config/database.yml` on the staging branch does not include a `staging:` entry, add it before rerunning.
Nginx config is applied once both env files exist and SSL files are installed.
Scripts generate `/etc/tradingsniperpanel/*.env` from each `.envrc` and install systemd units for Puma/Sidekiq.
Run the scripts with `sudo` from your admin user; they use `$SUDO_USER` as the app user and are not intended for direct root-only execution.
Optional override: force GitHub SSH port with `GITHUB_SSH_PORT=22` or `GITHUB_SSH_PORT=443` before running setup.

### SSH key troubleshooting (auto-detect app user)
If setup fails with `Permission denied (publickey)`, verify SSH auth as the same app user used by the scripts:
```
APP_USER="${SUDO_USER:-$USER}"
sudo -u "$APP_USER" -H env HOME="/home/$APP_USER" sh -lc 'cd "$HOME" && ls -la ~/.ssh && stat -c "%a %n" ~/.ssh ~/.ssh/* 2>/dev/null'
sudo -u "$APP_USER" -H env HOME="/home/$APP_USER" sh -lc 'cd "$HOME" && ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o HostName=ssh.github.com -p 443 -T git@github.com || true'
sudo -u "$APP_USER" -H env HOME="/home/$APP_USER" sh -lc 'cd "$HOME" && GIT_SSH_COMMAND="ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 -o ConnectionAttempts=1 -o HostName=ssh.github.com -p 443" git ls-remote git@github.com:loldlm1/tradingsniperpanel.com.git HEAD || true'
```
If you explicitly need to test port 22 instead, use:
```
sudo -u "$APP_USER" -H env HOME="/home/$APP_USER" sh -lc 'cd "$HOME" && GIT_SSH_COMMAND="ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 -o ConnectionAttempts=1" git ls-remote git@github.com:loldlm1/tradingsniperpanel.com.git HEAD || true'
```
If GitHub still rejects the key, regenerate and overwrite `/home/$APP_USER/.ssh/id_ed25519`, then add the new `.pub` key in GitHub:
```
APP_USER="${SUDO_USER:-$USER}"
sudo -u "$APP_USER" -H ssh-keygen -t ed25519 -f "/home/$APP_USER/.ssh/id_ed25519" -N ""
sudo -u "$APP_USER" -H cat "/home/$APP_USER/.ssh/id_ed25519.pub"
sudo -u "$APP_USER" -H env HOME="/home/$APP_USER" sh -lc 'cd "$HOME" && ssh -o BatchMode=yes -o HostName=ssh.github.com -p 443 -T git@github.com || true'
```
After key access is restored, rerun setup:
```
sudo bash /opt/tradingsniperpanel-deploy/setup_staging.sh
```

6) Stripe webhooks (staging):
- Webhook endpoint: `http://<staging-host>:48502/webhooks/stripe`
- The staging Nginx config bypasses the allowlist for `/webhooks/stripe` only.
- Recommended events (Pay + Checkout flows):
  - `checkout.session.completed`
  - `customer.subscription.created`
  - `customer.subscription.updated`
  - `customer.subscription.deleted`
  - `invoice.payment_succeeded`
  - `invoice.payment_failed`
  - `invoice.payment_action_required`
  - `payment_intent.succeeded`
  - `payment_intent.payment_failed`
Scripts run `db:seed` and `catalog:pandora:verify` on each deploy. Seed profiles default to `prod_mirror` in production and `full_qa` in staging/development; both converge the active commerce catalog on Pandora Box EA and are safe to re-run.
7) SSL files (production only):
```
CERT_SRC_DIR="$(pwd)"
sudo install -d /etc/ssl/tradingsniperpanel
sudo unzip -o "${CERT_SRC_DIR}/tradingsniperpanel.com-certificates.zip" -d /etc/ssl/tradingsniperpanel
# If the provider supplied a private key file in this folder, copy it. Otherwise use the key you generated with the CSR.
# Example (GoDaddy-style): sudo install -m 600 "${CERT_SRC_DIR}/tradingsniperpanel.com-PrivateKey.pem" /etc/ssl/tradingsniperpanel/privkey.pem
# Example (CSR key): sudo install -m 600 /path/to/tradingsniperpanel.com.key /etc/ssl/tradingsniperpanel/privkey.pem
sudo sh -c 'awk "1" \
  /etc/ssl/tradingsniperpanel/tradingsniperpanel.com-certificate.crt \
  /etc/ssl/tradingsniperpanel/tradingsniperpanel.com-intermediate.pem \
  /etc/ssl/tradingsniperpanel/tradingsniperpanel.com-root.pem \
  > /etc/ssl/tradingsniperpanel/fullchain.crt'
```
If your certificate bundle does not include a root file, omit it; `fullchain.crt` must include the leaf cert plus any intermediates. This step is safe to rerun and will rebuild the chain with proper newlines.
Rerun the production script to apply Nginx SSL.

### Rails console (staging + production)
Staging:
```
sudo -u "$USER" -H bash -lc 'cd /home/$USER/tradingsniperpanel.com-staging && set -a && source /etc/tradingsniperpanel/staging.env && set +a && bin/rails c -e staging'
```
Production:
```
sudo -u "$USER" -H bash -lc 'cd /home/$USER/tradingsniperpanel.com && set -a && source /etc/tradingsniperpanel/production.env && set +a && bin/rails c -e production'
```

### Staging reset (QA default)
This wipes staging data, rebuilds all databases, then reseeds with the full QA dataset:
```
sudo bash /home/$USER/tradingsniperpanel.com-staging/script/reset_staging_db.sh
```
To reseed staging with production-mirror data only:
```
sudo bash /home/$USER/tradingsniperpanel.com-staging/script/reset_staging_db.sh --prod-mirror-seed
```
For explicit `prod_mirror` modes:
- With DB clear (destructive): drop/recreate DBs, then `db:prepare db:seed`.
```
sudo bash /home/$USER/tradingsniperpanel.com-staging/script/reset_staging_db.sh reset --prod-mirror-seed
```
- Without DB clear (non-destructive): run `db:seed` only.
```
sudo bash /home/$USER/tradingsniperpanel.com-staging/script/reset_staging_db.sh seed --prod-mirror-seed
```
- Optional: apply migrations + reseed without dropping DBs.
```
sudo bash /home/$USER/tradingsniperpanel.com-staging/script/reset_staging_db.sh migrate-seed --prod-mirror-seed
```

### Staging Sidekiq cleanup (QA)
Clears Sidekiq retry/dead sets on staging:
```
sudo bash /home/$USER/tradingsniperpanel.com-staging/script/clear_sidekiq_staging.sh
```

### Manual steps (if you do not use the scripts)
1) Add Redis 7 APT repo (copy/paste):
```
sudo apt update
sudo apt install -y ca-certificates curl gnupg
sudo install -d -m 0755 /usr/share/keyrings
curl -fsSL https://packages.redis.io/gpg | sudo gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(. /etc/os-release && echo "$VERSION_CODENAME") main" | sudo tee /etc/apt/sources.list.d/redis.list > /dev/null
```
2) Install system packages (copy/paste):
```
sudo apt update && sudo apt install -y build-essential git curl libssl-dev libreadline-dev zlib1g-dev libyaml-dev libffi-dev libgdbm-dev libncurses5-dev libncursesw5-dev libbz2-dev libsqlite3-dev liblzma-dev libdb-dev libexpat1-dev tk-dev libpq-dev postgresql postgresql-contrib redis nginx unzip
```
3) Install asdf as your admin user:
```
git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.14.1
echo '. "$HOME/.asdf/asdf.sh"' >> ~/.bashrc
echo '. "$HOME/.asdf/completions/asdf.bash"' >> ~/.bashrc
source ~/.bashrc
```
4) Clone both environments and install tool versions:
```
git clone git@github.com:loldlm1/tradingsniperpanel.com.git /home/your_admin_user/tradingsniperpanel.com
git clone git@github.com:loldlm1/tradingsniperpanel.com.git /home/your_admin_user/tradingsniperpanel.com-staging
cd /home/your_admin_user/tradingsniperpanel.com && git checkout main
cd /home/your_admin_user/tradingsniperpanel.com-staging && git checkout staging
asdf plugin add ruby
asdf plugin add nodejs
asdf plugin add python
asdf plugin add uv
bash ~/.asdf/plugins/nodejs/bin/import-release-team-keyring
cd /home/your_admin_user/tradingsniperpanel.com && asdf install
cd /home/your_admin_user/tradingsniperpanel.com-staging && asdf install
```
5) Create `.envrc` in both directories (copy from `.envrc.example`) and fill production vs staging values, including `PORT`, `APP_HOST`, `APP_HOST_PROTOCOL`, `REDIS_URL`, and `STAGING_ALLOWLIST` for staging.
6) Install app dependencies in both directories:
```
cd /home/your_admin_user/tradingsniperpanel.com && bundle install --without development test && npm install
cd /home/your_admin_user/tradingsniperpanel.com-staging && bundle install --without development test && npm install
```
7) Enable Postgres and Redis:
```
sudo systemctl enable --now postgresql redis-server
```
8) Create the database user and databases (example, adjust names/passwords):
```
sudo -u postgres psql <<'SQL'
CREATE USER tradingsniperpanel WITH PASSWORD 'change_me';
CREATE DATABASE tradingsniperpanel_com_production OWNER tradingsniperpanel;
CREATE DATABASE tradingsniperpanel_com_production_cache OWNER tradingsniperpanel;
CREATE DATABASE tradingsniperpanel_com_production_queue OWNER tradingsniperpanel;
CREATE DATABASE tradingsniperpanel_com_production_cable OWNER tradingsniperpanel;
CREATE DATABASE tradingsniperpanel_com_staging OWNER tradingsniperpanel;
CREATE DATABASE tradingsniperpanel_com_staging_cache OWNER tradingsniperpanel;
CREATE DATABASE tradingsniperpanel_com_staging_queue OWNER tradingsniperpanel;
CREATE DATABASE tradingsniperpanel_com_staging_cable OWNER tradingsniperpanel;
SQL
```
9) Staging config:
- This repo includes `config/environments/staging.rb` (HTTP + no real mail delivery by default), so no manual copy from production is needed.
- Add a `staging:` entry in `/home/your_admin_user/tradingsniperpanel.com-staging/config/database.yml` by copying `production:` and renaming the env vars to `DB_NAME_STAGING`, `DB_NAME_STAGING_CACHE`, `DB_NAME_STAGING_QUEUE`, `DB_NAME_STAGING_CABLE`.
9) Create environment files for systemd (use `.envrc.example` as the full list reference).
```
sudo install -d -m 0755 /etc/tradingsniperpanel
```
Production example (`/etc/tradingsniperpanel/production.env`):
```
sudo tee /etc/tradingsniperpanel/production.env >/dev/null <<'EOF'
RAILS_ENV=production
PORT=48501
APP_HOST=tradingsniperpanel.com
APP_HOST_PROTOCOL=https
RAILS_MASTER_KEY=your_master_key
DATABASE_URL=postgres://tradingsniperpanel:change_me@localhost:5432/tradingsniperpanel_com_production
DB_NAME_PRODUCTION=tradingsniperpanel_com_production
DB_NAME_PRODUCTION_CACHE=tradingsniperpanel_com_production_cache
DB_NAME_PRODUCTION_QUEUE=tradingsniperpanel_com_production_queue
DB_NAME_PRODUCTION_CABLE=tradingsniperpanel_com_production_cable
REDIS_URL=redis://localhost:6379/0
RAILS_LOG_TO_STDOUT=1
RAILS_SERVE_STATIC_FILES=1
EOF
```

Staging example (`/etc/tradingsniperpanel/staging.env`):
```
sudo tee /etc/tradingsniperpanel/staging.env >/dev/null <<'EOF'
RAILS_ENV=staging
PORT=48502
APP_HOST=<staging-host>
APP_HOST_PROTOCOL=http
RAILS_MASTER_KEY=your_master_key
DATABASE_URL=postgres://tradingsniperpanel:change_me@localhost:5432/tradingsniperpanel_com_staging
DB_NAME_STAGING=tradingsniperpanel_com_staging
DB_NAME_STAGING_CACHE=tradingsniperpanel_com_staging_cache
DB_NAME_STAGING_QUEUE=tradingsniperpanel_com_staging_queue
DB_NAME_STAGING_CABLE=tradingsniperpanel_com_staging_cable
REDIS_URL=redis://localhost:6379/1
STAGING_ALLOWLIST=<your_client_ip>
RAILS_LOG_TO_STDOUT=1
RAILS_SERVE_STATIC_FILES=1
EOF
```
10) Prepare DBs and assets (load env files before running Rails tasks):
```
set -a; source /etc/tradingsniperpanel/production.env; set +a
cd /home/your_admin_user/tradingsniperpanel.com
bin/rails db:prepare db:seed assets:precompile

set -a; source /etc/tradingsniperpanel/staging.env; set +a
cd /home/your_admin_user/tradingsniperpanel.com-staging
bin/rails db:prepare db:seed assets:precompile
```
11) Systemd services (Puma + Sidekiq).

Production web (`/etc/systemd/system/tradingsniperpanel-production.service`):
```
[Unit]
Description=Trading Sniper Panel (production web)
After=network.target

[Service]
Type=simple
User=your_admin_user
WorkingDirectory=/home/your_admin_user/tradingsniperpanel.com
EnvironmentFile=/etc/tradingsniperpanel/production.env
Environment=PATH=/home/your_admin_user/.asdf/shims:/home/your_admin_user/.asdf/bin:/usr/local/bin:/usr/bin:/bin
ExecStart=/home/your_admin_user/.asdf/shims/bundle exec puma -C config/puma.rb
Restart=always
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target
```

Production Sidekiq (`/etc/systemd/system/tradingsniperpanel-sidekiq-production.service`):
```
[Unit]
Description=Trading Sniper Panel (production sidekiq)
After=network.target

[Service]
Type=simple
User=your_admin_user
WorkingDirectory=/home/your_admin_user/tradingsniperpanel.com
EnvironmentFile=/etc/tradingsniperpanel/production.env
Environment=PATH=/home/your_admin_user/.asdf/shims:/home/your_admin_user/.asdf/bin:/usr/local/bin:/usr/bin:/bin
ExecStart=/home/your_admin_user/.asdf/shims/bundle exec sidekiq -e production
Restart=always
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target
```

Staging web (`/etc/systemd/system/tradingsniperpanel-staging.service`):
```
[Unit]
Description=Trading Sniper Panel (staging web)
After=network.target

[Service]
Type=simple
User=your_admin_user
WorkingDirectory=/home/your_admin_user/tradingsniperpanel.com-staging
EnvironmentFile=/etc/tradingsniperpanel/staging.env
Environment=PATH=/home/your_admin_user/.asdf/shims:/home/your_admin_user/.asdf/bin:/usr/local/bin:/usr/bin:/bin
ExecStart=/home/your_admin_user/.asdf/shims/bundle exec puma -C config/puma.rb
Restart=always
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target
```

Staging Sidekiq (`/etc/systemd/system/tradingsniperpanel-sidekiq-staging.service`):
```
[Unit]
Description=Trading Sniper Panel (staging sidekiq)
After=network.target

[Service]
Type=simple
User=your_admin_user
WorkingDirectory=/home/your_admin_user/tradingsniperpanel.com-staging
EnvironmentFile=/etc/tradingsniperpanel/staging.env
Environment=PATH=/home/your_admin_user/.asdf/shims:/home/your_admin_user/.asdf/bin:/usr/local/bin:/usr/bin:/bin
ExecStart=/home/your_admin_user/.asdf/shims/bundle exec sidekiq -e staging
Restart=always
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target
```

Enable services:
```
sudo systemctl daemon-reload
sudo systemctl enable --now tradingsniperpanel-production.service
sudo systemctl enable --now tradingsniperpanel-sidekiq-production.service
sudo systemctl enable --now tradingsniperpanel-staging.service
sudo systemctl enable --now tradingsniperpanel-sidekiq-staging.service
```

12) SSL for production (DV certs are production only).
Copy the files to the server, then unpack and build a full chain:
```
sudo install -d /etc/ssl/tradingsniperpanel
sudo unzip tradingsniperpanel.com-certificates.zip -d /etc/ssl/tradingsniperpanel
sudo cp tradingsniperpanel.com-PrivateKey.pem /etc/ssl/tradingsniperpanel/privkey.pem
sudo ls /etc/ssl/tradingsniperpanel
```
Use the `.crt` files in the directory to create a full chain. Adjust filenames to match what the zip contains:
```
sudo cat /etc/ssl/tradingsniperpanel/tradingsniperpanel.com.crt /etc/ssl/tradingsniperpanel/ca_bundle.crt > /etc/ssl/tradingsniperpanel/fullchain.crt
```
The `tradingsniperpanel.com-CSR.pem` file is not used by Nginx.

13) Nginx config (production SSL + staging IP allowlist):
```
# /etc/nginx/sites-available/tradingsniperpanel.conf
upstream app_production {
  server 127.0.0.1:48501;
}

upstream app_staging {
  server 127.0.0.1:48502;
}

server {
  listen 80;
  server_name tradingsniperpanel.com www.tradingsniperpanel.com;
  return 301 https://tradingsniperpanel.com$request_uri;
}

server {
  listen 443 ssl http2;
  server_name tradingsniperpanel.com www.tradingsniperpanel.com;

  ssl_certificate /etc/ssl/tradingsniperpanel/fullchain.crt;
  ssl_certificate_key /etc/ssl/tradingsniperpanel/privkey.pem;

  location / {
    proxy_pass http://app_production;
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
  }
}

server {
  listen 80;
  server_name <staging-host>;

  location / {
    allow <your_client_ip>;
    deny all;

    proxy_pass http://app_staging;
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
  }
}
```
Enable the site:
```
sudo ln -s /etc/nginx/sites-available/tradingsniperpanel.conf /etc/nginx/sites-enabled/tradingsniperpanel.conf
sudo nginx -t
sudo systemctl reload nginx
```

14) Smoke tests:
```
curl -I https://tradingsniperpanel.com
curl -I http://<staging-host>
sudo systemctl status tradingsniperpanel-production.service
sudo systemctl status tradingsniperpanel-staging.service
```

## Environment variables (reference)
See `.envrc.example` for the full list. Key server variables:
- Rails: `RAILS_ENV`, `PORT`, `RAILS_MASTER_KEY`, `RAILS_LOG_TO_STDOUT`, `RAILS_SERVE_STATIC_FILES`.
- Host: `APP_HOST`, `APP_HOST_PROTOCOL`.
- Postgres: `DB_HOST`, `DB_PORT`, `DB_USERNAME`, `DB_PASSWORD`, `DATABASE_URL`, `DB_NAME_PRODUCTION*`, `DB_NAME_STAGING*`.
- Redis: `REDIS_URL`.
- Seeds: optional `SEED_PROFILE` override (`prod_mirror` or `full_qa`). Defaults are `prod_mirror` in production and `full_qa` in staging/development.
- Staging: `STAGING_ALLOWLIST` (space-separated IPs, wrap in quotes if multiple).
- Branding: `APP_NAME`, `APP_SHORT_NAME`, `LANDING_TEMPLATE`.
- Dashboard promotions: manage active Stripe promotion codes from ActiveAdmin; the dashboard modal is database-backed rather than env-driven.
- OAuth: `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, `GOOGLE_OAUTH_REDIRECT_URI`, `GOOGLE_HD`.
- Stripe (Pay): `STRIPE_PRIVATE_KEY`, `STRIPE_PUBLIC_KEY`, `STRIPE_SIGNING_SECRET`.
- Billing plans: the active catalog is seed-managed Pandora monthly/annual data in `billing_plans`; current and retired Stripe mappings are stored in `billing_plan_prices`.
- Licensing: `EA_LICENSE_PRIMARY_KEY`, `EA_LICENSE_SECRET_KEY`, `EA_LICENSE_SOURCE_ID`.
- Referrals: `REFER_DEFAULT_DISCOUNT_PERCENT`.
- MaxMind: `MAXMIND_LICENSE_KEY`, `MAXMIND_DB_PATH`.
- Support email: `SUPPORT_EMAIL`.
- SMTP (GoDaddy Microsoft 365 mailbox credentials): `SMTP_ADDRESS`, `SMTP_PORT`, `SMTP_DOMAIN`, `SMTP_USERNAME`, `SMTP_PASSWORD`, `SMTP_AUTHENTICATION`, `SMTP_ENABLE_STARTTLS_AUTO` (used for production runtime and explicit SMTP preflight tasks).

### SMTP notes (GoDaddy + Microsoft 365)
- `SMTP_USERNAME` / `SMTP_PASSWORD` are mailbox credentials (for example `support@your-domain.com`), not your GoDaddy account login.
- Default runtime behavior:
  - `production`: sends through SMTP when SMTP env vars are present.
  - `development` and `staging`: do not send real emails from normal app requests/jobs (`delivery_method = :test`, `perform_deliveries = false`).
  - `smtp:send_test`: explicit opt-in task that temporarily enables SMTP delivery for that task execution only.
- Typical values:
  - `SMTP_ADDRESS=smtp.office365.com`
  - `SMTP_PORT=587`
  - `SMTP_AUTHENTICATION=login`
  - `SMTP_ENABLE_STARTTLS_AUTO=true`
- Recommended timeouts:
  - `SMTP_OPEN_TIMEOUT=5`
  - `SMTP_READ_TIMEOUT=10`
- In GoDaddy Email & Office dashboard, enable SMTP Authentication for the mailbox user before deploying.

### SMTP preflight checks (before deploy)
- Validate SMTP handshake/auth only (no email sent):
```
bundle exec rails smtp:check
```
- Send an actual test email:
```
TO=you@example.com bundle exec rails smtp:send_test
```
- Staging server example:
```
sudo -u "$USER" -H bash -lc 'cd /home/$USER/tradingsniperpanel.com-staging && set -a && source /etc/tradingsniperpanel/staging.env && set +a && bundle exec rails smtp:check'
sudo -u "$USER" -H bash -lc 'cd /home/$USER/tradingsniperpanel.com-staging && set -a && source /etc/tradingsniperpanel/staging.env && set +a && TO=you@example.com bundle exec rails smtp:send_test'
```
- Production server example:
```
sudo -u "$USER" -H bash -lc 'cd /home/$USER/tradingsniperpanel.com && set -a && source /etc/tradingsniperpanel/production.env && set +a && bundle exec rails smtp:check'
sudo -u "$USER" -H bash -lc 'cd /home/$USER/tradingsniperpanel.com && set -a && source /etc/tradingsniperpanel/production.env && set +a && TO=you@example.com bundle exec rails smtp:send_test'
```

## Frontend notes
- Marketing/auth pages use Neon assets (`app/assets/templates/neon/...`), dashboard uses Mosaic (`app/assets/templates/mosaic/...`).
- Marketing pricing/resources live on the landing page sections; `/pricing` and `/docs` routes are removed.
- Default layouts: marketing (`application.html.erb`) and dashboard (`dashboard.html.erb`); locale toggle is in the header.

## Testing
```
bundle exec rspec
# with coverage gating (SimpleCov, 80% min):
COVERAGE=true bundle exec rspec
```

## Code standards
- Prefer POROs/service objects for business logic, I18n for copy (EN/ES), and view partials/components for repeated UI.
- Locale detection lives in `LocaleResolver` (param > session > user > GeoIP > Accept-Language > default); keep it lean and testable.
- Keep Stripe/Pay actions idempotent; webhook endpoints (from Pay) live under `/pay`.
- Respect referral cookies (`ref`) before sign-up; locale detection falls back to user session override.

## Stripe compliance notes (internal)
- Each client is the merchant of record; use their Stripe keys (BYO-Stripe) and keep product descriptions aligned with actual deliverables.
- Ensure `/terms`, `/privacy`, and `/refunds-and-cancellations` render on every custom domain with the client’s legal name, address, and support email.
- Avoid financial advice/earnings claims and do not market signals/copy-trading/account management features.
- Checkout disclosures: inline “no refunds / cancel anytime” notice on subscriptions; refund acknowledgement checkbox + server guard on marketplace purchases.
- Provide at least one public support method (email required; chat/Discord/Telegram optional).
