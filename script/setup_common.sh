#!/usr/bin/env bash
set -euo pipefail

REPO_URL_DEFAULT="git@github.com:loldlm1/tradingsniperpanel.com.git"
ENV_DIR="/etc/tradingsniperpanel"
SSL_DIR="/etc/ssl/tradingsniperpanel"
NGINX_CONF="/etc/nginx/sites-available/tradingsniperpanel.conf"
NGINX_ENABLED="/etc/nginx/sites-enabled/tradingsniperpanel.conf"

log() { printf "==> %s\n" "$*"; }
warn() { printf "WARN: %s\n" "$*" >&2; }
die() { printf "ERROR: %s\n" "$*" >&2; exit 1; }

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    die "Run this script with sudo."
  fi
}

detect_ssh_auth_sock() {
  local uid="$1"
  local user="$2"
  local sock
  local sockets=()

  if ! command -v ssh-add >/dev/null 2>&1; then
    return 1
  fi

  if [[ -d "/run/user/${uid}" ]]; then
    while IFS= read -r sock; do
      sockets+=("${sock}")
    done < <(find "/run/user/${uid}" -maxdepth 2 -type s \( -name "ssh-*" -o -name "ssh-agent*" \) -user "${user}" 2>/dev/null)
  fi

  while IFS= read -r sock; do
    sockets+=("${sock}")
  done < <(find /tmp -maxdepth 2 -type s -name "agent.*" -user "${user}" 2>/dev/null)

  for sock in "${sockets[@]}"; do
    if sudo -u "${user}" SSH_AUTH_SOCK="${sock}" ssh-add -L >/dev/null 2>&1; then
      printf "%s" "${sock}"
      return 0
    fi
  done

  return 1
}

init_app_user() {
  if [[ -z "${SUDO_USER:-}" ]]; then
    die "SUDO_USER is not set. Run with sudo from your admin user."
  fi

  APP_USER="${SUDO_USER}"
  APP_UID="$(id -u "${APP_USER}")"
  APP_HOME="$(getent passwd "${APP_USER}" | cut -d: -f6)"
  if [[ -z "${APP_HOME}" ]]; then
    die "Could not resolve home directory for ${APP_USER}."
  fi

  SSH_AUTH_SOCK_FALLBACK=""
  if [[ -z "${SSH_AUTH_SOCK:-}" ]]; then
    SSH_AUTH_SOCK_FALLBACK="$(detect_ssh_auth_sock "${APP_UID}" "${APP_USER}" || true)"
  fi
}

run_as_app_user() {
  local ssh_sock="${SSH_AUTH_SOCK:-}"
  if [[ -z "${ssh_sock}" && -n "${SSH_AUTH_SOCK_FALLBACK:-}" ]]; then
    ssh_sock="${SSH_AUTH_SOCK_FALLBACK}"
  fi
  if [[ -n "${ssh_sock}" ]]; then
    sudo -u "${APP_USER}" SSH_AUTH_SOCK="${ssh_sock}" bash -lc "[[ -f ~/.bashrc ]] && source ~/.bashrc; $*"
  else
    sudo -u "${APP_USER}" bash -lc "[[ -f ~/.bashrc ]] && source ~/.bashrc; $*"
  fi
}

ensure_packages() {
  log "Installing system packages"
  apt-get update
  apt-get install -y build-essential git curl libssl-dev libreadline-dev zlib1g-dev libyaml-dev libffi-dev libgdbm-dev libncurses5-dev libpq-dev postgresql postgresql-contrib redis-server nginx unzip
}

ensure_asdf() {
  if [[ ! -d "${APP_HOME}/.asdf" ]]; then
    log "Installing asdf"
    run_as_app_user "git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.14.1"
  fi

  run_as_app_user "grep -q '.asdf/asdf.sh' ~/.bashrc || echo '. \"\$HOME/.asdf/asdf.sh\"' >> ~/.bashrc"
  run_as_app_user "grep -q '.asdf/completions/asdf.bash' ~/.bashrc || echo '. \"\$HOME/.asdf/completions/asdf.bash\"' >> ~/.bashrc"
}

ensure_asdf_plugins() {
  if ! run_as_app_user "asdf plugin list | grep -qx ruby"; then
    log "Adding asdf ruby plugin"
    run_as_app_user "asdf plugin add ruby"
  fi

  if ! run_as_app_user "asdf plugin list | grep -qx nodejs"; then
    log "Adding asdf nodejs plugin"
    run_as_app_user "asdf plugin add nodejs"
    if run_as_app_user "test -f ~/.asdf/plugins/nodejs/bin/import-release-team-keyring"; then
      run_as_app_user "bash ~/.asdf/plugins/nodejs/bin/import-release-team-keyring"
    else
      warn "Nodejs keyring script not found; skipping import."
    fi
  fi
}

ensure_repo() {
  local repo_url="$1"
  local app_dir="$2"
  local branch="$3"
  local git_env=""

  if [[ "${repo_url}" == git@* || "${repo_url}" == ssh://* ]]; then
    git_env="GIT_SSH_COMMAND='ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new' GIT_TERMINAL_PROMPT=0"
    if ! run_as_app_user "ssh-add -L >/dev/null 2>&1"; then
      die "SSH agent has no keys loaded. Run ssh-add as ${APP_USER} and rerun (or set REPO_URL to HTTPS)."
    fi
  else
    git_env="GIT_TERMINAL_PROMPT=0"
  fi

  if [[ ! -d "${app_dir}/.git" ]]; then
    log "Cloning repo into ${app_dir}"
    run_as_app_user "${git_env} git clone '${repo_url}' '${app_dir}'"
  fi

  local origin
  origin="$(run_as_app_user "cd '${app_dir}' && ${git_env} git remote get-url origin")"
  if [[ "${origin}" != "${repo_url}" ]]; then
    die "Repo origin mismatch at ${app_dir}. Expected ${repo_url}, got ${origin}."
  fi

  run_as_app_user "cd '${app_dir}' && ${git_env} git fetch origin"

  if ! run_as_app_user "cd '${app_dir}' && git diff --quiet --ignore-submodules --"; then
    die "Uncommitted changes in ${app_dir}. Commit or stash before running setup."
  fi
  if ! run_as_app_user "cd '${app_dir}' && git diff --cached --quiet --ignore-submodules --"; then
    die "Staged changes in ${app_dir}. Commit or unstage before running setup."
  fi

  if ! run_as_app_user "cd '${app_dir}' && ${git_env} git ls-remote --exit-code --heads origin '${branch}' >/dev/null"; then
    die "Branch '${branch}' not found on origin."
  fi

  if run_as_app_user "cd '${app_dir}' && git show-ref --verify --quiet 'refs/heads/${branch}'"; then
    run_as_app_user "cd '${app_dir}' && ${git_env} git checkout '${branch}'"
  else
    run_as_app_user "cd '${app_dir}' && ${git_env} git checkout -b '${branch}' 'origin/${branch}'"
  fi

  run_as_app_user "cd '${app_dir}' && ${git_env} git pull --ff-only"
}

ensure_envrc() {
  local app_dir="$1"
  local envrc="${app_dir}/.envrc"
  local example="${app_dir}/.envrc.example"

  if [[ -f "${envrc}" ]]; then
    return
  fi

  if [[ -f "${example}" ]]; then
    log "Creating ${envrc} from .envrc.example"
    run_as_app_user "cp '${example}' '${envrc}'"
    die "Fill in ${envrc} and rerun the setup."
  fi

  die "Missing ${envrc}. Add it and rerun the setup."
}

require_env_keys() {
  local envrc="$1"
  shift
  local missing=()
  local key

  for key in "$@"; do
    if ! grep -Eq "^export ${key}=" "${envrc}"; then
      missing+=("${key}")
    fi
  done

  if (( ${#missing[@]} > 0 )); then
    die "Missing required vars in ${envrc}: ${missing[*]}"
  fi
}

get_envrc_value() {
  local key="$1"
  local envrc="$2"
  local line

  line="$(grep -E "^export ${key}=" "${envrc}" | tail -n1 || true)"
  line="${line#export ${key}=}"
  line="${line%\"}"
  line="${line#\"}"
  printf "%s" "${line}"
}

get_env_value() {
  local key="$1"
  local env_file="$2"
  local line

  line="$(grep -E "^${key}=" "${env_file}" | tail -n1 || true)"
  line="${line#${key}=}"
  line="${line%\"}"
  line="${line#\"}"
  printf "%s" "${line}"
}

render_env_file() {
  local envrc="$1"
  local dest="$2"
  local rails_env="$3"
  local tmp
  local filtered

  tmp="$(mktemp)"
  filtered="$(mktemp)"

  grep -E '^export [A-Za-z_][A-Za-z0-9_]*=' "${envrc}" | sed 's/^export //' > "${tmp}"
  grep -Ev '^(RAILS_ENV|RAILS_LOG_TO_STDOUT|RAILS_SERVE_STATIC_FILES)=' "${tmp}" > "${filtered}"
  printf "RAILS_ENV=%s\nRAILS_LOG_TO_STDOUT=1\nRAILS_SERVE_STATIC_FILES=1\n" "${rails_env}" >> "${filtered}"
  if ! grep -Eq '^BIND_HOST=' "${filtered}" && [[ "${rails_env}" == "staging" || "${rails_env}" == "production" ]]; then
    printf "BIND_HOST=127.0.0.1\n" >> "${filtered}"
  fi

  install -d -m 0755 "$(dirname "${dest}")"
  if [[ ! -f "${dest}" ]] || ! cmp -s "${filtered}" "${dest}"; then
    install -m 0640 "${filtered}" "${dest}"
    log "Wrote ${dest}"
  fi

  if [[ -f "${dest}" && -n "${APP_USER:-}" ]]; then
    chown root:"${APP_USER}" "${dest}"
    chmod 0640 "${dest}"
  fi

  rm -f "${tmp}" "${filtered}"
}

sql_escape() {
  local value="$1"
  printf "%s" "${value//\'/\'\'}"
}

psql_as_postgres() {
  ( cd / && sudo -u postgres -H psql "$@" )
}

ensure_postgres_role() {
  local role="$1"
  local password="$2"
  local escaped

  if psql_as_postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='${role}'" | grep -q 1; then
    log "Postgres role ${role} already exists"
    return
  fi

  escaped="$(sql_escape "${password}")"
  log "Creating Postgres role ${role}"
  psql_as_postgres -v ON_ERROR_STOP=1 -c "CREATE USER ${role} WITH PASSWORD '${escaped}';"
}

ensure_postgres_db() {
  local db_name="$1"
  local owner="$2"

  if psql_as_postgres -tAc "SELECT 1 FROM pg_database WHERE datname='${db_name}'" | grep -q 1; then
    log "Database ${db_name} already exists"
    return
  fi

  log "Creating database ${db_name}"
  psql_as_postgres -v ON_ERROR_STOP=1 -c "CREATE DATABASE ${db_name} OWNER ${owner};"
}

drop_postgres_db() {
  local db_name="$1"

  log "Dropping database ${db_name}"
  psql_as_postgres -v ON_ERROR_STOP=1 -c "DROP DATABASE IF EXISTS ${db_name};"
}

check_service_active() {
  local service="$1"

  if systemctl is-active --quiet "${service}"; then
    log "Service ${service} is active"
    return 0
  fi

  warn "Service ${service} is not active"
  return 1
}

check_http_status() {
  local label="$1"
  local url="$2"
  local ok_regex="$3"
  shift 3
  local code=""
  local attempt

  for attempt in 1 2 3 4 5; do
    if code="$(curl -sS -o /dev/null -w "%{http_code}" --max-time 8 "$@" "${url}")"; then
      if [[ "${code}" =~ ${ok_regex} ]]; then
        log "${label} responded with ${code}"
        return 0
      fi
    else
      code="curl_error"
    fi
    sleep 2
  done

  warn "${label} did not respond with expected status (last: ${code})"
  return 1
}

install_app_deps() {
  local app_dir="$1"

  log "Installing Ruby and Node versions"
  run_as_app_user "cd '${app_dir}' && asdf install"

  log "Installing Ruby gems"
  run_as_app_user "cd '${app_dir}' && bundle install --without development test"

  log "Installing npm packages"
  run_as_app_user "cd '${app_dir}' && npm install"
}

prepare_app_assets() {
  local app_dir="$1"
  local rails_env="$2"

  log "Preparing database, seeds, and assets"
  run_as_app_user "cd '${app_dir}' && set -a && source .envrc && set +a && RAILS_ENV='${rails_env}' bin/rails db:prepare db:seed assets:precompile"
}

write_file_if_changed() {
  local dest="$1"
  local content="$2"
  local tmp

  tmp="$(mktemp)"
  printf "%s\n" "${content}" > "${tmp}"

  if [[ ! -f "${dest}" ]] || ! cmp -s "${tmp}" "${dest}"; then
    install -m 0644 "${tmp}" "${dest}"
    log "Updated ${dest}"
  fi

  rm -f "${tmp}"
}

render_systemd_unit() {
  local unit_name="$1"
  local unit_body="$2"
  local unit_path="/etc/systemd/system/${unit_name}"

  write_file_if_changed "${unit_path}" "${unit_body}"
}

ensure_nginx_config() {
  local prod_env_file="$1"
  local staging_env_file="$2"
  local require_ssl="${3:-1}"

  local has_prod=0
  local has_staging=0
  [[ -f "${prod_env_file}" ]] && has_prod=1
  [[ -f "${staging_env_file}" ]] && has_staging=1

  if [[ "${has_prod}" -eq 0 && "${has_staging}" -eq 0 ]]; then
    warn "Skipping Nginx config (missing env files)."
    return 0
  fi

  local prod_host prod_port staging_host staging_port allowlist
  if [[ "${has_prod}" -eq 1 ]]; then
    prod_host="$(get_env_value APP_HOST "${prod_env_file}")"
    prod_port="$(get_env_value PORT "${prod_env_file}")"
    if [[ -z "${prod_host}" || -z "${prod_port}" ]]; then
      die "Missing APP_HOST/PORT in ${prod_env_file}; cannot render Nginx config."
    fi
  else
    log "Production env not found; generating staging-only Nginx config."
  fi

  if [[ "${has_staging}" -eq 1 ]]; then
    staging_host="$(get_env_value APP_HOST "${staging_env_file}")"
    staging_port="$(get_env_value PORT "${staging_env_file}")"
    allowlist="$(get_env_value STAGING_ALLOWLIST "${staging_env_file}")"
    if [[ -z "${staging_host}" || -z "${staging_port}" || -z "${allowlist}" ]]; then
      die "Missing APP_HOST/PORT/STAGING_ALLOWLIST in ${staging_env_file}; cannot render Nginx config."
    fi
  else
    log "Staging env not found; generating production-only Nginx config."
  fi

  local cert="${SSL_DIR}/fullchain.crt"
  local key="${SSL_DIR}/privkey.pem"
  local include_prod=0
  local include_staging=0

  if [[ "${has_prod}" -eq 1 ]]; then
    if [[ ! -f "${cert}" || ! -f "${key}" ]]; then
      if [[ "${require_ssl}" -eq 1 ]]; then
        die "SSL cert files missing in ${SSL_DIR}. Install them and rerun."
      fi
      warn "Skipping production Nginx block (SSL cert files missing)."
    else
      include_prod=1
    fi
  fi

  if [[ "${has_staging}" -eq 1 ]]; then
    include_staging=1
  fi

  if [[ "${include_prod}" -eq 0 && "${include_staging}" -eq 0 ]]; then
    warn "Skipping Nginx config (no usable env configuration)."
    return 0
  fi

  local allow_lines=""
  local staging_domain=""
  local prod_domain=""
  if [[ "${include_staging}" -eq 1 ]]; then
    allowlist="${allowlist//,/ }"
    local ip
    for ip in ${allowlist}; do
      allow_lines="${allow_lines}    allow ${ip};\n"
    done
    allow_lines="${allow_lines}    deny all;\n"
    staging_domain="${staging_host%%:*}"
  fi

  if [[ "${include_prod}" -eq 1 ]]; then
    prod_domain="${prod_host%%:*}"
  fi

  local upstreams=""
  if [[ "${include_prod}" -eq 1 ]]; then
    upstreams="${upstreams}upstream app_production {\n  server 127.0.0.1:${prod_port};\n}\n\n"
  fi
  if [[ "${include_staging}" -eq 1 ]]; then
    upstreams="${upstreams}upstream app_staging {\n  server 127.0.0.1:${staging_port};\n}\n\n"
  fi

  local prod_block=""
  if [[ "${include_prod}" -eq 1 ]]; then
    prod_block="$(cat <<EOF
server {
  listen 80;
  server_name ${prod_domain} www.${prod_domain};
  return 301 https://${prod_domain}\$request_uri;
}

server {
  listen 443 ssl http2;
  server_name ${prod_domain} www.${prod_domain};

  ssl_certificate ${cert};
  ssl_certificate_key ${key};

  location / {
    proxy_pass http://app_production;
    proxy_http_version 1.1;
    proxy_set_header Host \$host;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
  }
}

EOF
)"
  fi

  local staging_block=""
  if [[ "${include_staging}" -eq 1 ]]; then
    staging_block="$(cat <<EOF
server {
  listen 80;
  server_name ${staging_domain};

  location = /webhooks/stripe {
    proxy_pass http://app_staging;
    proxy_http_version 1.1;
    proxy_set_header Host \$host;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
  }

  location / {
$(printf "%b" "${allow_lines}")    proxy_pass http://app_staging;
    proxy_http_version 1.1;
    proxy_set_header Host \$host;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
  }
}
EOF
)"
  fi

  local nginx_body
  nginx_body="$(cat <<EOF
# /etc/nginx/sites-available/tradingsniperpanel.conf
$(printf "%b" "${upstreams}")${prod_block}${staging_block}
EOF
)"

  local backup=""
  if [[ -f "${NGINX_CONF}" ]]; then
    backup="$(mktemp)"
    cp "${NGINX_CONF}" "${backup}"
  fi

  write_file_if_changed "${NGINX_CONF}" "${nginx_body}"

  if [[ -L "${NGINX_ENABLED}" ]]; then
    local target
    target="$(readlink -f "${NGINX_ENABLED}")"
    if [[ "${target}" != "${NGINX_CONF}" ]]; then
      ln -sf "${NGINX_CONF}" "${NGINX_ENABLED}"
    fi
  elif [[ -e "${NGINX_ENABLED}" ]]; then
    warn "${NGINX_ENABLED} exists and is not a symlink; skipping symlink update."
  else
    ln -s "${NGINX_CONF}" "${NGINX_ENABLED}"
  fi

  if ! nginx -t; then
    if [[ -n "${backup}" ]]; then
      cp "${backup}" "${NGINX_CONF}"
    fi
    die "Nginx config test failed. Fix config and rerun."
  fi

  systemctl reload nginx
  log "Reloaded Nginx"
}
