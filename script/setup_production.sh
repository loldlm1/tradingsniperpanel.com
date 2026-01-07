#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=script/setup_common.sh
source "${SCRIPT_DIR}/setup_common.sh"

require_root
init_app_user

REPO_URL="${REPO_URL:-${REPO_URL_DEFAULT}}"
APP_DIR="/home/${APP_USER}/tradingsniperpanel.com"
BRANCH="main"
ENVRC="${APP_DIR}/.envrc"
ENV_FILE="${ENV_DIR}/production.env"

ensure_packages
ensure_asdf
ensure_asdf_plugins
ensure_repo "${REPO_URL}" "${APP_DIR}" "${BRANCH}"
ensure_envrc "${APP_DIR}"

require_env_keys "${ENVRC}" \
  APP_HOST \
  APP_HOST_PROTOCOL \
  DB_HOST \
  DB_PORT \
  DB_USERNAME \
  DB_PASSWORD \
  DB_NAME_PRODUCTION \
  DB_NAME_PRODUCTION_CACHE \
  DB_NAME_PRODUCTION_QUEUE \
  DB_NAME_PRODUCTION_CABLE \
  PORT \
  RAILS_MASTER_KEY \
  REDIS_URL

render_env_file "${ENVRC}" "${ENV_FILE}" "production"

db_user="$(get_envrc_value DB_USERNAME "${ENVRC}")"
db_password="$(get_envrc_value DB_PASSWORD "${ENVRC}")"
db_primary="$(get_envrc_value DB_NAME_PRODUCTION "${ENVRC}")"
db_cache="$(get_envrc_value DB_NAME_PRODUCTION_CACHE "${ENVRC}")"
db_queue="$(get_envrc_value DB_NAME_PRODUCTION_QUEUE "${ENVRC}")"
db_cable="$(get_envrc_value DB_NAME_PRODUCTION_CABLE "${ENVRC}")"

systemctl enable --now postgresql redis-server
ensure_postgres_role "${db_user}" "${db_password}"
ensure_postgres_db "${db_primary}" "${db_user}"
ensure_postgres_db "${db_cache}" "${db_user}"
ensure_postgres_db "${db_queue}" "${db_user}"
ensure_postgres_db "${db_cable}" "${db_user}"

install_app_deps "${APP_DIR}"
prepare_app_assets "${APP_DIR}" "production"

render_systemd_unit "tradingsniperpanel-production.service" "[Unit]
Description=Trading Sniper Panel (production web)
After=network.target

[Service]
Type=simple
User=${APP_USER}
WorkingDirectory=${APP_DIR}
EnvironmentFile=${ENV_FILE}
Environment=PATH=${APP_HOME}/.asdf/shims:${APP_HOME}/.asdf/bin:/usr/local/bin:/usr/bin:/bin
ExecStart=${APP_HOME}/.asdf/shims/bundle exec puma -C config/puma.rb
Restart=always
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target"

render_systemd_unit "tradingsniperpanel-sidekiq-production.service" "[Unit]
Description=Trading Sniper Panel (production sidekiq)
After=network.target

[Service]
Type=simple
User=${APP_USER}
WorkingDirectory=${APP_DIR}
EnvironmentFile=${ENV_FILE}
Environment=PATH=${APP_HOME}/.asdf/shims:${APP_HOME}/.asdf/bin:/usr/local/bin:/usr/bin:/bin
ExecStart=${APP_HOME}/.asdf/shims/bundle exec sidekiq -e production
Restart=always
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target"

systemctl daemon-reload
systemctl enable --now tradingsniperpanel-production.service
systemctl enable --now tradingsniperpanel-sidekiq-production.service
systemctl restart tradingsniperpanel-production.service
systemctl restart tradingsniperpanel-sidekiq-production.service

ensure_nginx_config "${ENV_FILE}" "${ENV_DIR}/staging.env" 1

verify_failed=0
prod_host="$(get_env_value APP_HOST "${ENV_FILE}")"
prod_domain="${prod_host%%:*}"
prod_port="$(get_env_value PORT "${ENV_FILE}")"

check_service_active "tradingsniperpanel-production.service" || verify_failed=1
check_service_active "tradingsniperpanel-sidekiq-production.service" || verify_failed=1
check_service_active "nginx" || verify_failed=1
check_http_status "Production app (direct)" "http://127.0.0.1:${prod_port}" "^[23][0-9]{2}$" -H "Host: ${prod_domain}" || verify_failed=1
check_http_status "Production app (via Nginx)" "http://127.0.0.1/" "^(200|301|302)$" -H "Host: ${prod_domain}" || verify_failed=1

log "Rails logs (production): sudo journalctl -u tradingsniperpanel-production.service -f"
log "Sidekiq logs (production): sudo journalctl -u tradingsniperpanel-sidekiq-production.service -f"
log "Nginx access log: sudo tail -f /var/log/nginx/access.log"
log "Nginx error log: sudo tail -f /var/log/nginx/error.log"

if (( verify_failed )); then
  die "Production verification failed. Check the logs above."
fi

log "Production setup complete."
