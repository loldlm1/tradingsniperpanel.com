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

chown root:"${APP_USER}" "${ENV_FILE}"
chmod 0640 "${ENV_FILE}"

log "Clearing Sidekiq retry and dead sets (staging)"
run_as_app_user "set -a && source '${ENV_FILE}' && set +a && cd '${APP_DIR}' && '${BUNDLE_BIN}' exec rails runner \"require 'sidekiq/api'; Sidekiq::RetrySet.new.clear; Sidekiq::DeadSet.new.clear\""

log "Sidekiq staging cleanup complete."
