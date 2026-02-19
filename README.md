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

## Server setup (Ubuntu 22.04, staging + production on the same VPS)

### Recommended: setup scripts
1) Add your server SSH key to GitHub for `git@github.com:loldlm1/tradingsniperpanel.com.git`.
2) Copy the deploy scripts somewhere outside the repo (example path below). Copy/paste from this repo or `scp` them in:
```
sudo install -d /opt/tradingsniperpanel-deploy
# Copy these files into /opt/tradingsniperpanel-deploy: setup_common.sh, setup_production.sh, setup_staging.sh
sudo chmod +x /opt/tradingsniperpanel-deploy/setup_production.sh /opt/tradingsniperpanel-deploy/setup_staging.sh
```
3) Run production setup from the external script (it will clone the repo and self-update the local scripts if needed):
```
sudo bash /opt/tradingsniperpanel-deploy/setup_production.sh
```
If SSL files are not installed yet, the script will stop after setup; install certs and rerun.
If your SSH key has a passphrase, load it into ssh-agent before running the script (for example: `eval "$(ssh-agent -s)" && ssh-add ~/.ssh/id_ed25519`). The scripts try to detect your agent; if they still complain, run with `sudo -E` to preserve `SSH_AUTH_SOCK`.
On first run it will create `/home/$USER/tradingsniperpanel.com/.envrc` and exit. Fill it with production values (`APP_HOST=tradingsniperpanel.com`, `APP_HOST_PROTOCOL=https`, `PORT=48501`, `REDIS_URL=redis://localhost:6379/0`, `DB_HOST`, `DB_PORT`, `DB_USERNAME`, `DB_PASSWORD`, and all `DB_NAME_PRODUCTION*` values), then rerun the same command.
4) Run staging setup:
```
sudo bash /opt/tradingsniperpanel-deploy/setup_staging.sh
```
On first run, it will create `/home/$USER/tradingsniperpanel.com-staging/.envrc` and exit. Fill it with staging values (`APP_HOST=<staging-host>`, `APP_HOST_PROTOCOL=http`, `PORT=48502`, `REDIS_URL=redis://localhost:6379/1`, `DB_HOST`, `DB_PORT`, `DB_USERNAME`, `DB_PASSWORD`, `DB_NAME_STAGING*`, `STAGING_ALLOWLIST=<your_client_ip>`), then rerun.
If `config/database.yml` on the staging branch does not include a `staging:` entry, add it before rerunning.
Nginx config is applied once both env files exist and SSL files are installed.
Scripts generate `/etc/tradingsniperpanel/*.env` from each `.envrc` and install systemd units for Puma/Sidekiq.
Run the scripts with `sudo` from your admin user; they will use `$SUDO_USER` as the app user.
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
Scripts run `db:seed` on each deploy. Seed profiles default to `prod_mirror` in production and `full_qa` in staging/development, and are safe to re-run.
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
9) Add staging config files in the staging app:
```
cp /home/your_admin_user/tradingsniperpanel.com-staging/config/environments/production.rb /home/your_admin_user/tradingsniperpanel.com-staging/config/environments/staging.rb
```
In `config/environments/staging.rb`, set:
- `config.assume_ssl = false`
- `config.force_ssl = false`

Add a `staging:` entry in `/home/your_admin_user/tradingsniperpanel.com-staging/config/database.yml` by copying `production:` and renaming the env vars to `DB_NAME_STAGING`, `DB_NAME_STAGING_CACHE`, `DB_NAME_STAGING_QUEUE`, `DB_NAME_STAGING_CABLE`.
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
- OAuth: `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, `GOOGLE_OAUTH_REDIRECT_URI`, `GOOGLE_HD`.
- Stripe (Pay): `STRIPE_PRIVATE_KEY`, `STRIPE_PUBLIC_KEY`, `STRIPE_SIGNING_SECRET`.
- Billing plans: stored in `billing_plans` and created via `Billing::PlanCreator` (see `db/seeds`).
- Licensing: `EA_LICENSE_PRIMARY_KEY`, `EA_LICENSE_SECRET_KEY`, `EA_LICENSE_SOURCE_ID`.
- Referrals: `REFER_DEFAULT_DISCOUNT_PERCENT`.
- MaxMind: `MAXMIND_LICENSE_KEY`, `MAXMIND_DB_PATH`.
- Support email: `SUPPORT_EMAIL`.
- SMTP (GoDaddy Microsoft 365 mailbox credentials): `SMTP_ADDRESS`, `SMTP_PORT`, `SMTP_DOMAIN`, `SMTP_USERNAME`, `SMTP_PASSWORD`, `SMTP_AUTHENTICATION`, `SMTP_ENABLE_STARTTLS_AUTO`.

### SMTP notes (GoDaddy + Microsoft 365)
- `SMTP_USERNAME` / `SMTP_PASSWORD` are mailbox credentials (for example `support@your-domain.com`), not your GoDaddy account login.
- Typical values:
  - `SMTP_ADDRESS=smtp.office365.com`
  - `SMTP_PORT=587`
  - `SMTP_AUTHENTICATION=login`
  - `SMTP_ENABLE_STARTTLS_AUTO=true`
- In GoDaddy Email & Office dashboard, enable SMTP Authentication for the mailbox user before deploying.

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
