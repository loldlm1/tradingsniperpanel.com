#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=script/setup_common.sh
source "${SCRIPT_DIR}/setup_common.sh"

usage() {
  cat <<'EOF'
Usage: reset_staging_db.sh [reset|migrate|seed|migrate-seed]

Actions:
  reset         Drop and recreate staging databases, then db:prepare and db:seed (default).
  migrate       Run db:migrate only.
  seed          Run db:seed only.
  migrate-seed  Run db:migrate followed by db:seed.
EOF
}

require_root
init_app_user

APP_DIR="/home/${APP_USER}/tradingsniperpanel.com-staging"
ENV_FILE="${ENV_DIR}/staging.env"
BUNDLE_BIN="${APP_HOME}/.asdf/shims/bundle"
ACTION="${1:-reset}"

if [[ ! -f "${ENV_FILE}" ]]; then
  die "Missing ${ENV_FILE}. Run staging setup first."
fi

if [[ ! -d "${APP_DIR}" ]]; then
  die "Missing ${APP_DIR}. Run staging setup first."
fi

if [[ ! -x "${BUNDLE_BIN}" ]]; then
  die "Missing ${BUNDLE_BIN}. Install Ruby with asdf and rerun."
fi

case "${ACTION}" in
  reset|migrate|seed|migrate-seed) ;;
  -h|--help)
    usage
    exit 0
    ;;
  *)
    usage
    die "Unknown action: ${ACTION}"
    ;;
esac

chown root:"${APP_USER}" "${ENV_FILE}"
chmod 0640 "${ENV_FILE}"

db_user="$(get_env_value DB_USERNAME "${ENV_FILE}")"
db_password="$(get_env_value DB_PASSWORD "${ENV_FILE}")"
db_primary="$(get_env_value DB_NAME_STAGING "${ENV_FILE}")"
db_cache="$(get_env_value DB_NAME_STAGING_CACHE "${ENV_FILE}")"
db_queue="$(get_env_value DB_NAME_STAGING_QUEUE "${ENV_FILE}")"
db_cable="$(get_env_value DB_NAME_STAGING_CABLE "${ENV_FILE}")"

log "Stopping staging services"
systemctl stop tradingsniperpanel-staging.service tradingsniperpanel-sidekiq-staging.service

ensure_postgres_role "${db_user}" "${db_password}"
if [[ "${ACTION}" == "reset" ]]; then
  log "Resetting staging databases"
  drop_postgres_db "${db_cable}"
  drop_postgres_db "${db_queue}"
  drop_postgres_db "${db_cache}"
  drop_postgres_db "${db_primary}"
fi

ensure_postgres_db "${db_primary}" "${db_user}"
ensure_postgres_db "${db_cache}" "${db_user}"
ensure_postgres_db "${db_queue}" "${db_user}"
ensure_postgres_db "${db_cable}" "${db_user}"

case "${ACTION}" in
  reset)
    run_as_app_user "set -a && source '${ENV_FILE}' && set +a && cd '${APP_DIR}' && '${BUNDLE_BIN}' exec rails db:prepare db:seed"
    ;;
  migrate)
    run_as_app_user "set -a && source '${ENV_FILE}' && set +a && cd '${APP_DIR}' && '${BUNDLE_BIN}' exec rails db:migrate"
    ;;
  seed)
    run_as_app_user "set -a && source '${ENV_FILE}' && set +a && cd '${APP_DIR}' && '${BUNDLE_BIN}' exec rails db:seed"
    ;;
  migrate-seed)
    run_as_app_user "set -a && source '${ENV_FILE}' && set +a && cd '${APP_DIR}' && '${BUNDLE_BIN}' exec rails db:migrate db:seed"
    ;;
esac

log "Starting staging services"
systemctl start tradingsniperpanel-staging.service tradingsniperpanel-sidekiq-staging.service

log "Staging ${ACTION} complete."
