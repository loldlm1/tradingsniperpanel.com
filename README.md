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
1) Install system packages (copy/paste):
```
sudo apt update && sudo apt install -y build-essential git curl libssl-dev libreadline-dev zlib1g-dev libyaml-dev libffi-dev libgdbm-dev libncurses5-dev libpq-dev postgresql postgresql-contrib redis-server nginx unzip
```
2) Create the deploy user (skip if it already exists):
```
sudo adduser deploy
sudo usermod -aG sudo deploy
```
3) Login as deploy and install asdf:
```
su - deploy
git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.14.1
echo '. "$HOME/.asdf/asdf.sh"' >> ~/.bashrc
echo '. "$HOME/.asdf/completions/asdf.bash"' >> ~/.bashrc
source ~/.bashrc
```
4) Clone the repo and install tool versions:
```
git clone <your_repo_url> /home/deploy/tradingsniperpanel.com
cd /home/deploy/tradingsniperpanel.com
asdf plugin add ruby
asdf plugin add nodejs
bash ~/.asdf/plugins/nodejs/bin/import-release-team-keyring
asdf install
```
5) Install app dependencies:
```
bundle install --without development test
npm install
```
6) Enable Postgres and Redis:
```
sudo systemctl enable --now postgresql redis-server
```
7) Create the database user and databases (example, adjust names/passwords):
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
8) Add staging config files in the app:
```
cp config/environments/production.rb config/environments/staging.rb
```
In `config/environments/staging.rb`, set:
- `config.assume_ssl = false`
- `config.force_ssl = false`

Add a `staging:` entry in `config/database.yml` by copying `production:` and renaming the env vars to `DB_NAME_STAGING`, `DB_NAME_STAGING_CACHE`, `DB_NAME_STAGING_QUEUE`, `DB_NAME_STAGING_CABLE`.
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
APP_HOST=82.86.112.106
APP_HOST_PROTOCOL=http
RAILS_MASTER_KEY=your_master_key
DATABASE_URL=postgres://tradingsniperpanel:change_me@localhost:5432/tradingsniperpanel_com_staging
DB_NAME_STAGING=tradingsniperpanel_com_staging
DB_NAME_STAGING_CACHE=tradingsniperpanel_com_staging_cache
DB_NAME_STAGING_QUEUE=tradingsniperpanel_com_staging_queue
DB_NAME_STAGING_CABLE=tradingsniperpanel_com_staging_cable
REDIS_URL=redis://localhost:6379/1
RAILS_LOG_TO_STDOUT=1
RAILS_SERVE_STATIC_FILES=1
EOF
```
10) Prepare DBs and assets (load env files before running Rails tasks):
```
set -a; source /etc/tradingsniperpanel/production.env; set +a
bin/rails db:prepare assets:precompile

set -a; source /etc/tradingsniperpanel/staging.env; set +a
bin/rails db:prepare assets:precompile
```
11) Systemd services (Puma + Sidekiq).

Production web (`/etc/systemd/system/tradingsniperpanel-production.service`):
```
[Unit]
Description=Trading Sniper Panel (production web)
After=network.target

[Service]
Type=simple
User=deploy
WorkingDirectory=/home/deploy/tradingsniperpanel.com
EnvironmentFile=/etc/tradingsniperpanel/production.env
Environment=PATH=/home/deploy/.asdf/shims:/home/deploy/.asdf/bin:/usr/local/bin:/usr/bin:/bin
ExecStart=/home/deploy/.asdf/shims/bundle exec puma -C config/puma.rb
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
User=deploy
WorkingDirectory=/home/deploy/tradingsniperpanel.com
EnvironmentFile=/etc/tradingsniperpanel/production.env
Environment=PATH=/home/deploy/.asdf/shims:/home/deploy/.asdf/bin:/usr/local/bin:/usr/bin:/bin
ExecStart=/home/deploy/.asdf/shims/bundle exec sidekiq -e production
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
User=deploy
WorkingDirectory=/home/deploy/tradingsniperpanel.com
EnvironmentFile=/etc/tradingsniperpanel/staging.env
Environment=PATH=/home/deploy/.asdf/shims:/home/deploy/.asdf/bin:/usr/local/bin:/usr/bin:/bin
ExecStart=/home/deploy/.asdf/shims/bundle exec puma -C config/puma.rb
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
User=deploy
WorkingDirectory=/home/deploy/tradingsniperpanel.com
EnvironmentFile=/etc/tradingsniperpanel/staging.env
Environment=PATH=/home/deploy/.asdf/shims:/home/deploy/.asdf/bin:/usr/local/bin:/usr/bin:/bin
ExecStart=/home/deploy/.asdf/shims/bundle exec sidekiq -e staging
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

13) Nginx config (production SSL + staging IP allowlist). Replace the allowlist IPs with your own:
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
  server_name 82.86.112.106;

  location / {
    allow 203.0.113.10;
    allow 198.51.100.20;
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
curl -I http://82.86.112.106
sudo systemctl status tradingsniperpanel-production.service
sudo systemctl status tradingsniperpanel-staging.service
```

## Environment variables (reference)
See `.envrc.example` for the full list. Key server variables:
- Rails: `RAILS_ENV`, `PORT`, `RAILS_MASTER_KEY`, `RAILS_LOG_TO_STDOUT`, `RAILS_SERVE_STATIC_FILES`.
- Host: `APP_HOST`, `APP_HOST_PROTOCOL`.
- Postgres: `DATABASE_URL`, `DB_NAME_PRODUCTION*`, `DB_NAME_STAGING*`.
- Redis: `REDIS_URL`.
- Branding: `APP_NAME`, `APP_SHORT_NAME`, `LANDING_TEMPLATE`.
- OAuth: `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, `GOOGLE_OAUTH_REDIRECT_URI`, `GOOGLE_HD`.
- Stripe (Pay): `STRIPE_PRIVATE_KEY`, `STRIPE_PUBLIC_KEY`, `STRIPE_SIGNING_SECRET`, plus all plan price IDs.
- Licensing: `EA_LICENSE_PRIMARY_KEY`, `EA_LICENSE_SECRET_KEY`, `EA_LICENSE_SOURCE_ID`.
- Referrals: `REFER_DEFAULT_DISCOUNT_PERCENT`.
- MaxMind: `MAXMIND_LICENSE_KEY`, `MAXMIND_DB_PATH`.
- Support email: `SUPPORT_EMAIL`.

## Frontend notes
- Marketing/auth pages use Neon assets (`app/assets/templates/neon/...`), dashboard uses Mosaic (`app/assets/templates/mosaic/...`).
- Marketing pricing/resources live on the landing page sections; `/pricing` and `/docs` routes are removed.
- Docs/manuals are exposed under `public/docs/sniper_advanced_panel/` (EN/ES Markdown + PDFs).
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
