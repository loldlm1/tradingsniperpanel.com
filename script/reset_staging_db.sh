#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=script/setup_common.sh
source "${SCRIPT_DIR}/setup_common.sh"

usage() {
  cat <<'EOF'
Usage: reset_staging_db.sh [ACTION] [--target staging|production] [--confirm-production-reset]

Actions:
  reset         Drop and recreate databases, then db:prepare and db:seed (default).
  migrate       Run db:migrate only.
  seed          Run db:seed only.
  migrate-seed  Run db:migrate followed by db:seed.

Options:
  --target <env>              Target environment: staging (default) or production.
  --confirm-production-reset  Required for production reset. Also requires typing a confirmation token.
  -h, --help                  Show this help message.

Examples:
  reset_staging_db.sh
  reset_staging_db.sh migrate --target staging
  reset_staging_db.sh reset --target production --confirm-production-reset
EOF
}

confirm_production_reset() {
  local token="RESET_PRODUCTION_DATABASES"
  local typed_token

  if [[ "${CONFIRM_PRODUCTION_RESET}" -ne 1 ]]; then
    warn "Production reset requested without explicit confirmation."
    die "Re-run with --confirm-production-reset to acknowledge the destructive action."
  fi

  if [[ ! -t 0 ]]; then
    die "Production reset requires an interactive shell for typed confirmation."
  fi

  warn "DANGER: This will permanently drop and recreate all production databases."
  warn "Databases: ${db_primary}, ${db_cache}, ${db_queue}, ${db_cable}"
  printf "Type %s to continue: " "${token}"
  read -r typed_token
  if [[ "${typed_token}" != "${token}" ]]; then
    die "Confirmation token mismatch. Aborting."
  fi
}

ACTION="reset"
TARGET="staging"
CONFIRM_PRODUCTION_RESET=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    reset|migrate|seed|migrate-seed)
      ACTION="$1"
      shift
      ;;
    --target)
      [[ $# -ge 2 ]] || die "Missing value for --target."
      TARGET="$2"
      shift 2
      ;;
    --target=*)
      TARGET="${1#*=}"
      shift
      ;;
    --confirm-production-reset)
      CONFIRM_PRODUCTION_RESET=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage
      die "Unknown argument: $1"
      ;;
  esac
done

case "${TARGET}" in
  staging|production) ;;
  *)
    usage
    die "Unknown target: ${TARGET}. Use staging or production."
    ;;
esac

require_root
init_app_user

BUNDLE_BIN="${APP_HOME}/.asdf/shims/bundle"
APP_DIR=""
ENV_FILE=""
ENV_SETUP_HINT=""
db_primary_key=""
db_cache_key=""
db_queue_key=""
db_cable_key=""
web_service=""
sidekiq_service=""

case "${TARGET}" in
  staging)
    APP_DIR="/home/${APP_USER}/tradingsniperpanel.com-staging"
    ENV_FILE="${ENV_DIR}/staging.env"
    ENV_SETUP_HINT="staging"
    db_primary_key="DB_NAME_STAGING"
    db_cache_key="DB_NAME_STAGING_CACHE"
    db_queue_key="DB_NAME_STAGING_QUEUE"
    db_cable_key="DB_NAME_STAGING_CABLE"
    web_service="tradingsniperpanel-staging.service"
    sidekiq_service="tradingsniperpanel-sidekiq-staging.service"
    ;;
  production)
    APP_DIR="/home/${APP_USER}/tradingsniperpanel.com"
    ENV_FILE="${ENV_DIR}/production.env"
    ENV_SETUP_HINT="production"
    db_primary_key="DB_NAME_PRODUCTION"
    db_cache_key="DB_NAME_PRODUCTION_CACHE"
    db_queue_key="DB_NAME_PRODUCTION_QUEUE"
    db_cable_key="DB_NAME_PRODUCTION_CABLE"
    web_service="tradingsniperpanel-production.service"
    sidekiq_service="tradingsniperpanel-sidekiq-production.service"
    ;;
esac

if [[ ! -f "${ENV_FILE}" ]]; then
  die "Missing ${ENV_FILE}. Run ${ENV_SETUP_HINT} setup first."
fi

if [[ ! -d "${APP_DIR}" ]]; then
  die "Missing ${APP_DIR}. Run ${ENV_SETUP_HINT} setup first."
fi

if [[ ! -x "${BUNDLE_BIN}" ]]; then
  die "Missing ${BUNDLE_BIN}. Install Ruby with asdf and rerun."
fi

case "${ACTION}" in
  reset|migrate|seed|migrate-seed) ;;
  *)
    usage
    die "Unknown action: ${ACTION}"
    ;;
esac

chown root:"${APP_USER}" "${ENV_FILE}"
chmod 0640 "${ENV_FILE}"

db_user="$(get_env_value DB_USERNAME "${ENV_FILE}")"
db_password="$(get_env_value DB_PASSWORD "${ENV_FILE}")"
db_primary="$(get_env_value "${db_primary_key}" "${ENV_FILE}")"
db_cache="$(get_env_value "${db_cache_key}" "${ENV_FILE}")"
db_queue="$(get_env_value "${db_queue_key}" "${ENV_FILE}")"
db_cable="$(get_env_value "${db_cable_key}" "${ENV_FILE}")"

if [[ "${TARGET}" == "production" && "${ACTION}" == "reset" ]]; then
  confirm_production_reset
fi

log "Stopping ${TARGET} services"
systemctl stop "${web_service}" "${sidekiq_service}"

ensure_postgres_role "${db_user}" "${db_password}"
if [[ "${ACTION}" == "reset" ]]; then
  log "Resetting ${TARGET} databases"
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

log "Starting ${TARGET} services"
systemctl start "${web_service}" "${sidekiq_service}"

log "${TARGET^} ${ACTION} complete."
