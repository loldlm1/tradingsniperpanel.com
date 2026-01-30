# SSL automation for production deploy

## Goal
Automate SSL provisioning in deploy scripts so a clean Ubuntu 22.04 VPS can obtain and install certificates and Nginx config without manual SSL file copying, while supporting per-client domains.

## Definition of Done
- Running the external `script/setup_production.sh` on a clean VPS provisions SSL (or fails with clear actionable errors) and brings up Nginx + app.
- SSL certs are stored securely on the server (not committed in git), and renewals are configured.
- Supports either single-domain or multiple client domains via env configuration.
- Nginx config renders correctly and `nginx -t` passes for both production and staging.
- Deployment docs and `.envrc.example` (or env docs) are updated with new keys.

## Constraints
- Deploy scripts run outside the repo and re-exec from repo after clone (first run clones, second run configures).
- SSL keys must not be committed in the repo.
- Must work on Ubuntu 22.04 with minimal dependencies.
- SaaS: domains may change per client.

## Steps
1. Decide certificate strategy: Let’s Encrypt via `certbot` or `acme.sh`; choose HTTP-01 vs DNS-01 (wildcard) based on domain needs.
2. Add env configuration for domains and SSL mode (e.g., `APP_DOMAINS`, `SSL_MODE`, `SSL_EMAIL`, `SSL_DIR`).
3. Implement SSL provisioning function/script to install tooling, issue/renew certs, and store keys under `/etc/ssl/tradingsniperpanel` or `/etc/letsencrypt/live`.
4. Update `ensure_nginx_config` to handle multiple domains or wildcard certs.
5. Add docs for provisioning + renewal and update example env files.
6. Verify on a clean VPS run: first run clones, second run provisions SSL + Nginx + app successfully.

## Open Questions
- Are client domains subdomains you control, or arbitrary custom domains (CNAME)?
- Which DNS provider(s) do you use, and do you have API access for DNS-01?
- Is a wildcard cert acceptable (single base domain), or do you need per-domain certs?
- Do you want to stick with Nginx or consider Caddy for automatic TLS?
- Where should renewal be handled (certbot timer vs cron)?
