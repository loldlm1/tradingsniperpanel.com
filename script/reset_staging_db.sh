#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=script/setup_common.sh
source "${SCRIPT_DIR}/setup_common.sh"

require_root
init_app_user

APP_DIR="/home/${APP_USER}/tradingsniperpanel.com-staging"
ENV_FILE="${ENV_DIR}/staging.env"
BUNDLE_BIN="${APP_HOME}/.asdf/shims/bundle"

if [[ ! -f "${ENV_FILE}" ]]; then
  die "Missing ${ENV_FILE}. Run staging setup first."
fi

if [[ ! -d "${APP_DIR}" ]]; then
  die "Missing ${APP_DIR}. Run staging setup first."
fi

if [[ ! -x "${BUNDLE_BIN}" ]]; then
  die "Missing ${BUNDLE_BIN}. Install Ruby with asdf and rerun."
fi

log "Stopping staging services"
systemctl stop tradingsniperpanel-staging.service tradingsniperpanel-sidekiq-staging.service

log "Resetting staging databases"
set -a
# shellcheck disable=SC1090
source "${ENV_FILE}"
set +a

sudo -E -u "${APP_USER}" bash -lc "cd '${APP_DIR}' && '${BUNDLE_BIN}' exec rails db:drop:all db:prepare db:seed"

log "Starting staging services"
systemctl start tradingsniperpanel-staging.service tradingsniperpanel-sidekiq-staging.service

log "Staging reset complete."
