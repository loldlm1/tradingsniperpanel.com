#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=script/setup_common.sh
source "${SCRIPT_DIR}/setup_common.sh"

require_root
init_app_user

REPO_URL="${REPO_URL:-${REPO_URL_DEFAULT}}"
APP_DIR="/home/${APP_USER}/tradingsniperpanel.com-staging"
BRANCH="staging"
ENVRC="${APP_DIR}/.envrc"
ENV_FILE="${ENV_DIR}/staging.env"

ensure_packages
ensure_asdf
ensure_asdf_plugins
ensure_repo "${REPO_URL}" "${APP_DIR}" "${BRANCH}"
ensure_envrc "${APP_DIR}"

if [[ ! -f "${APP_DIR}/config/environments/staging.rb" ]]; then
  log "Creating config/environments/staging.rb from production"
  run_as_app_user "cp '${APP_DIR}/config/environments/production.rb' '${APP_DIR}/config/environments/staging.rb'"
  run_as_app_user "sed -i 's/config.assume_ssl = true/config.assume_ssl = false/' '${APP_DIR}/config/environments/staging.rb'"
  run_as_app_user "sed -i 's/config.force_ssl = true/config.force_ssl = false/' '${APP_DIR}/config/environments/staging.rb'"
else
  if grep -q "config.assume_ssl = true" "${APP_DIR}/config/environments/staging.rb"; then
    die "config/environments/staging.rb still assumes SSL. Set it to false and rerun."
  fi
  if grep -q "config.force_ssl = true" "${APP_DIR}/config/environments/staging.rb"; then
    die "config/environments/staging.rb still forces SSL. Set it to false and rerun."
  fi
fi

if ! grep -q "^staging:" "${APP_DIR}/config/database.yml"; then
  die "Missing staging config in config/database.yml. Add it before running staging setup."
fi

require_env_keys "${ENVRC}" \
  APP_HOST \
  APP_HOST_PROTOCOL \
  DB_HOST \
  DB_PORT \
  DB_USERNAME \
  DB_PASSWORD \
  DB_NAME_STAGING \
  DB_NAME_STAGING_CACHE \
  DB_NAME_STAGING_QUEUE \
  DB_NAME_STAGING_CABLE \
  PORT \
  RAILS_MASTER_KEY \
  REDIS_URL \
  STAGING_ALLOWLIST

render_env_file "${ENVRC}" "${ENV_FILE}" "staging"

db_user="$(get_envrc_value DB_USERNAME "${ENVRC}")"
db_password="$(get_envrc_value DB_PASSWORD "${ENVRC}")"
db_primary="$(get_envrc_value DB_NAME_STAGING "${ENVRC}")"
db_cache="$(get_envrc_value DB_NAME_STAGING_CACHE "${ENVRC}")"
db_queue="$(get_envrc_value DB_NAME_STAGING_QUEUE "${ENVRC}")"
db_cable="$(get_envrc_value DB_NAME_STAGING_CABLE "${ENVRC}")"

systemctl enable --now postgresql redis-server
ensure_postgres_role "${db_user}" "${db_password}"
ensure_postgres_db "${db_primary}" "${db_user}"
ensure_postgres_db "${db_cache}" "${db_user}"
ensure_postgres_db "${db_queue}" "${db_user}"
ensure_postgres_db "${db_cable}" "${db_user}"

install_app_deps "${APP_DIR}"
prepare_app_assets "${APP_DIR}" "staging"

render_systemd_unit "tradingsniperpanel-staging.service" "[Unit]
Description=Trading Sniper Panel (staging web)
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

render_systemd_unit "tradingsniperpanel-sidekiq-staging.service" "[Unit]
Description=Trading Sniper Panel (staging sidekiq)
After=network.target

[Service]
Type=simple
User=${APP_USER}
WorkingDirectory=${APP_DIR}
EnvironmentFile=${ENV_FILE}
Environment=PATH=${APP_HOME}/.asdf/shims:${APP_HOME}/.asdf/bin:/usr/local/bin:/usr/bin:/bin
ExecStart=${APP_HOME}/.asdf/shims/bundle exec sidekiq -e staging
Restart=always
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target"

systemctl daemon-reload
systemctl enable --now tradingsniperpanel-staging.service
systemctl enable --now tradingsniperpanel-sidekiq-staging.service
systemctl restart tradingsniperpanel-staging.service
systemctl restart tradingsniperpanel-sidekiq-staging.service

ensure_nginx_config "${ENV_DIR}/production.env" "${ENV_FILE}" 0

log "Staging setup complete."
