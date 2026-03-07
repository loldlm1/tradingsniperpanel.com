#!/usr/bin/env bash
set -euo pipefail

# XRDP + xorgxrdp + XFCE setup and maintenance for Ubuntu 22.04.
# Designed for SSH-tunneled RDP access with xfreerdp and session reuse.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME="${0##*/}"

DEFAULT_DESKTOP_USER="${SUDO_USER:-}"
if [[ -z "${DEFAULT_DESKTOP_USER}" || "${DEFAULT_DESKTOP_USER}" == "root" ]]; then
  DEFAULT_DESKTOP_USER="admin"
fi

DESKTOP_USER="${DESKTOP_USER:-${ADMIN_USER:-${DEFAULT_DESKTOP_USER}}}"
RDP_PORT="${RDP_PORT:-43389}"
RDP_BIND_ADDR="${RDP_BIND_ADDR:-127.0.0.1}"
RDP_PORT_CONFIG="${RDP_PORT_CONFIG:-tcp://${RDP_BIND_ADDR}:${RDP_PORT}}"
LOCAL_TUNNEL_PORT="${LOCAL_TUNNEL_PORT:-13389}"
PASSWORDLESS_SUDO="${PASSWORDLESS_SUDO:-true}"
SSH_PORT="${SSH_PORT:-22}"
ENABLE_UFW="${ENABLE_UFW:-false}"
COPY_CALLER_SSH_KEYS="${COPY_CALLER_SSH_KEYS:-true}"
ADMIN_SSH_KEY="${ADMIN_SSH_KEY:-}"
ADMIN_SSH_KEY_FILE="${ADMIN_SSH_KEY_FILE:-}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-}"
XRDP_STATE_DIR="${XRDP_STATE_DIR:-/var/lib/tradingsniperpanel/xrdp}"
AUTO_CLEANUP_DUPLICATES="${AUTO_CLEANUP_DUPLICATES:-true}"
OUTPUT_SERVER_IP="${SERVER_IP:-}"

if [[ -z "${OUTPUT_SERVER_IP}" && -n "${SSH_CONNECTION:-}" ]]; then
  OUTPUT_SERVER_IP="$(awk '{print $3}' <<<"${SSH_CONNECTION}")"
fi
if [[ -z "${OUTPUT_SERVER_IP}" ]]; then
  OUTPUT_SERVER_IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
fi
if [[ -z "${OUTPUT_SERVER_IP}" ]]; then
  OUTPUT_SERVER_IP="<server_ip>"
fi

WITH_SESMAN_RESTART="false"
ACTION="help"
TARGET_HOME=""

XRDP_CHANGED=0
SESMAN_CHANGED=0
LOGIND_CHANGED=0
UPOWER_CHANGED=0
FAIL2BAN_CHANGED=0
BOOTSTRAP_PASSWORD=""
BOOTSTRAP_PASSWORD_FILE=""
BOOTSTRAP_PASSWORD_WAS_GENERATED=0
BOOTSTRAP_KEY_SOURCE="none"
BOOTSTRAP_PASSWORD_SOURCE="none"

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

warn() {
  printf '[%s] WARN: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >&2
}

die() {
  printf '[%s] ERROR: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >&2
  exit 1
}

usage() {
  cat <<EOF
Usage: ${SCRIPT_NAME} <action> [options]

Actions:
  setup          Install and configure XRDP, xorgxrdp, XFCE, and user bootstrap
  status         Show service state and XRDP sessions for the target user
  cleanup        Keep the newest XRDP session and terminate all older XRDP sessions
  safe-restart   Reset XRDP cleanly: terminate XRDP sessions and restart services
  restart-all    Alias for the same clean XRDP reset behavior
  verify         Validate packages, config, services, and listening state
  help           Show this help

Options:
  --user <name>      Override DESKTOP_USER/ADMIN_USER
  --with-sesman      Legacy compatibility flag; ignored by current reset workflow
  -h, --help         Show this help

Environment overrides:
  DESKTOP_USER / ADMIN_USER   Target desktop user (default: ${DEFAULT_DESKTOP_USER})
  ADMIN_PASSWORD              Explicit password to set for the target user
  ADMIN_SSH_KEY               Public key content to install for the target user
  ADMIN_SSH_KEY_FILE          Public key file to install for the target user
  COPY_CALLER_SSH_KEYS        Copy SUDO_USER *.pub keys when available (default: ${COPY_CALLER_SSH_KEYS})
  PASSWORDLESS_SUDO           true/false (default: ${PASSWORDLESS_SUDO})
  ENABLE_UFW                  true/false (default: ${ENABLE_UFW})
  SSH_PORT                    SSH port to allow if UFW is enabled (default: ${SSH_PORT})
  RDP_PORT                    Server-side XRDP port (default: ${RDP_PORT})
  LOCAL_TUNNEL_PORT           Client-side forwarded port (default: ${LOCAL_TUNNEL_PORT})
  AUTO_CLEANUP_DUPLICATES     true/false cleanup after restart (default: ${AUTO_CLEANUP_DUPLICATES})
EOF
}

parse_args() {
  if [[ $# -eq 0 ]]; then
    usage
    exit 0
  fi

  ACTION="$1"
  shift

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --user)
        [[ $# -ge 2 ]] || die "--user requires a value"
        DESKTOP_USER="$2"
        shift 2
        ;;
      --with-sesman)
        WITH_SESMAN_RESTART="true"
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "Unknown option: $1"
        ;;
    esac
  done

  case "${ACTION}" in
    setup|status|cleanup|safe-restart|restart-all|verify|help)
      ;;
    *)
      die "Unknown action: ${ACTION}"
      ;;
  esac

  if [[ "${ACTION}" == "restart-all" ]]; then
    WITH_SESMAN_RESTART="true"
  fi
}

require_root() {
  [[ "${EUID}" -eq 0 ]] || die "Run this script with sudo or as root."
}

ensure_target_user_resolved() {
  [[ -n "${DESKTOP_USER}" ]] || die "DESKTOP_USER/ADMIN_USER cannot be empty."
  [[ "${DESKTOP_USER}" != "root" ]] || die "DESKTOP_USER/ADMIN_USER must not be root."

  if id "${DESKTOP_USER}" >/dev/null 2>&1; then
    TARGET_HOME="$(getent passwd "${DESKTOP_USER}" | cut -d: -f6)"
  fi
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

bool_true() {
  case "${1:-false}" in
    1|true|TRUE|yes|YES|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

ensure_directory() {
  local path="$1"
  local mode="$2"
  local owner="$3"
  local group="$4"

  if [[ ! -d "${path}" ]]; then
    install -d -m "${mode}" -o "${owner}" -g "${group}" "${path}"
  else
    chmod "${mode}" "${path}"
    chown "${owner}:${group}" "${path}"
  fi
}

backup_file() {
  local file="$1"
  if [[ -f "${file}" && ! -f "${file}.bak" ]]; then
    cp -p "${file}" "${file}.bak"
  fi
}

write_file_if_changed() {
  local path="$1"
  local mode="$2"
  local owner="$3"
  local group="$4"
  local tmp

  tmp="$(mktemp)"
  cat >"${tmp}"

  if [[ ! -f "${path}" ]] || ! cmp -s "${tmp}" "${path}"; then
    backup_file "${path}"
    install -m "${mode}" -o "${owner}" -g "${group}" "${tmp}" "${path}"
    rm -f "${tmp}"
    return 0
  fi

  rm -f "${tmp}"
  chmod "${mode}" "${path}"
  chown "${owner}:${group}" "${path}"
  return 1
}

ensure_line_in_file() {
  local line="$1"
  local file="$2"

  touch "${file}"
  if ! grep -Fqx "${line}" "${file}"; then
    printf '%s\n' "${line}" >>"${file}"
    return 0
  fi
  return 1
}

ensure_group_membership() {
  local user="$1"
  local group="$2"

  if ! id -nG "${user}" | tr ' ' '\n' | grep -Fxq "${group}"; then
    usermod -a -G "${group}" "${user}"
    return 0
  fi
  return 1
}

ensure_packages_installed() {
  local missing=()
  local pkg

  for pkg in "$@"; do
    if ! dpkg -s "${pkg}" >/dev/null 2>&1; then
      missing+=("${pkg}")
    fi
  done

  if [[ ${#missing[@]} -eq 0 ]]; then
    return 1
  fi

  log "Installing packages: ${missing[*]}"
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y "${missing[@]}"
  return 0
}

ini_set() {
  local file="$1"
  local section="$2"
  local key="$3"
  local value="$4"
  local tmp
  local mode
  local owner
  local group

  [[ -f "${file}" ]] || die "INI file not found: ${file}"

  tmp="$(mktemp)"
  mode="$(stat -c '%a' "${file}")"
  owner="$(stat -c '%u' "${file}")"
  group="$(stat -c '%g' "${file}")"

  awk -v section="${section}" -v key="${key}" -v value="${value}" '
    BEGIN {
      in_section = 0
      inserted = 0
      section_found = 0
      section_regex = "^[[:space:]]*\\[" section "\\][[:space:]]*$"
      key_regex = "^[[:space:]]*" key "[[:space:]]*="
    }
    /^[[:space:]]*\[.*\][[:space:]]*$/ {
      if (in_section && !inserted) {
        print key "=" value
        inserted = 1
      }
      in_section = ($0 ~ section_regex)
      if (in_section) {
        section_found = 1
      }
      print
      next
    }
    {
      if (in_section && $0 ~ key_regex) {
        next
      }
      print
    }
    END {
      if (section_found && in_section && !inserted) {
        print key "=" value
      }
    }
  ' "${file}" >"${tmp}"

  if ! cmp -s "${tmp}" "${file}"; then
    backup_file "${file}"
    mv "${tmp}" "${file}"
    chmod "${mode}" "${file}"
    chown "${owner}:${group}" "${file}"
    return 0
  fi

  rm -f "${tmp}"
  return 1
}

ini_get() {
  local file="$1"
  local section="$2"
  local key="$3"

  awk -v section="${section}" -v key="${key}" '
    BEGIN {
      in_section = 0
      section_regex = "^[[:space:]]*\\[" section "\\][[:space:]]*$"
      key_regex = "^[[:space:]]*" key "[[:space:]]*="
    }
    /^[[:space:]]*\[.*\][[:space:]]*$/ {
      in_section = ($0 ~ section_regex)
      next
    }
    in_section && $0 ~ key_regex {
      sub(/^[^=]*=[[:space:]]*/, "", $0)
      gsub(/[[:space:]]+$/, "", $0)
      print
      exit
    }
  ' "${file}"
}

wait_for_xrdp() {
  local port="$1"
  local bind_addr="$2"
  local tries="${3:-15}"
  local listen_addr=""
  local i

  if ! command_exists ss; then
    warn "ss not found; skipping XRDP port validation."
    return 0
  fi

  for ((i = 1; i <= tries; i += 1)); do
    listen_addr="$(ss -ltnp 2>/dev/null | awk -v p=":${port}" '$4 ~ p {print $4; exit}')"
    case "${listen_addr}" in
      "${bind_addr}:"*|127.0.0.1:*|[::1]:*)
        return 0
        ;;
      "")
        sleep 1
        ;;
      *)
        warn "XRDP is listening on ${listen_addr} (expected ${bind_addr}:${port})."
        return 1
        ;;
    esac
  done

  return 1
}

wait_for_xrdp_stopped() {
  local port="$1"
  local tries="${2:-15}"
  local listen_addr=""
  local i

  if ! command_exists ss; then
    sleep 2
    return 0
  fi

  for ((i = 1; i <= tries; i += 1)); do
    listen_addr="$(ss -ltnp 2>/dev/null | awk -v p=":${port}" '$4 ~ p {print $4; exit}')"
    if [[ -z "${listen_addr}" ]]; then
      return 0
    fi
    sleep 1
  done

  return 1
}

generate_random_password() {
  if command_exists openssl; then
    openssl rand -base64 24 | tr -d '\n'
    return
  fi

  head -c 32 /dev/urandom | base64 | tr -d '\n'
}

ensure_state_dir() {
  ensure_directory "${XRDP_STATE_DIR}" 0700 root root
}

persist_bootstrap_password() {
  local password="$1"

  ensure_state_dir
  BOOTSTRAP_PASSWORD_FILE="${XRDP_STATE_DIR}/${DESKTOP_USER}.password"
  printf '%s\n' "${password}" >"${BOOTSTRAP_PASSWORD_FILE}"
  chmod 0600 "${BOOTSTRAP_PASSWORD_FILE}"
  chown root:root "${BOOTSTRAP_PASSWORD_FILE}"
}

determine_bootstrap_password() {
  ensure_state_dir
  BOOTSTRAP_PASSWORD_FILE="${XRDP_STATE_DIR}/${DESKTOP_USER}.password"

  if [[ -n "${ADMIN_PASSWORD}" ]]; then
    BOOTSTRAP_PASSWORD="${ADMIN_PASSWORD}"
    BOOTSTRAP_PASSWORD_SOURCE="provided"
    return
  fi

  if [[ -f "${BOOTSTRAP_PASSWORD_FILE}" ]]; then
    BOOTSTRAP_PASSWORD="$(<"${BOOTSTRAP_PASSWORD_FILE}")"
    BOOTSTRAP_PASSWORD_SOURCE="stored"
    return
  fi

  BOOTSTRAP_PASSWORD="$(generate_random_password)"
  persist_bootstrap_password "${BOOTSTRAP_PASSWORD}"
  BOOTSTRAP_PASSWORD_WAS_GENERATED=1
  BOOTSTRAP_PASSWORD_SOURCE="generated"
}

ensure_desktop_user() {
  local user_created=0

  if ! id "${DESKTOP_USER}" >/dev/null 2>&1; then
    log "Creating desktop user: ${DESKTOP_USER}"
    useradd -m -s /bin/bash -U "${DESKTOP_USER}"
    user_created=1
  fi

  TARGET_HOME="$(getent passwd "${DESKTOP_USER}" | cut -d: -f6)"
  [[ -n "${TARGET_HOME}" && -d "${TARGET_HOME}" ]] || die "Could not resolve home directory for ${DESKTOP_USER}."

  if ensure_group_membership "${DESKTOP_USER}" "sudo"; then
    log "Added ${DESKTOP_USER} to sudo group."
  fi

  determine_bootstrap_password

  if [[ "${BOOTSTRAP_PASSWORD_SOURCE}" == "provided" || "${BOOTSTRAP_PASSWORD_WAS_GENERATED}" -eq 1 || "${user_created}" -eq 1 ]]; then
    printf '%s:%s\n' "${DESKTOP_USER}" "${BOOTSTRAP_PASSWORD}" | chpasswd
    if [[ "${BOOTSTRAP_PASSWORD_SOURCE}" == "provided" ]]; then
      persist_bootstrap_password "${BOOTSTRAP_PASSWORD}"
    fi
    log "Updated password for ${DESKTOP_USER} using ${BOOTSTRAP_PASSWORD_SOURCE} bootstrap credentials."
  else
    log "Leaving existing ${DESKTOP_USER} password unchanged."
  fi

  if bool_true "${PASSWORDLESS_SUDO}"; then
    if write_file_if_changed "/etc/sudoers.d/90-${DESKTOP_USER}-nopasswd" 0440 root root <<EOF
${DESKTOP_USER} ALL=(ALL) NOPASSWD:ALL
EOF
    then
      log "Configured passwordless sudo for ${DESKTOP_USER}."
    fi
  else
    rm -f "/etc/sudoers.d/90-${DESKTOP_USER}-nopasswd"
  fi
}

install_public_key_content() {
  local key_content="$1"
  local ssh_dir="${TARGET_HOME}/.ssh"
  local auth_keys="${ssh_dir}/authorized_keys"

  ensure_directory "${ssh_dir}" 0700 "${DESKTOP_USER}" "${DESKTOP_USER}"
  touch "${auth_keys}"
  chmod 0600 "${auth_keys}"
  chown "${DESKTOP_USER}:${DESKTOP_USER}" "${auth_keys}"

  ensure_line_in_file "${key_content}" "${auth_keys}" >/dev/null || true
  chown "${DESKTOP_USER}:${DESKTOP_USER}" "${auth_keys}"
  return 0
}

copy_caller_public_keys() {
  local caller="${SUDO_USER:-}"
  local caller_home=""
  local key_file
  local copied=0

  if [[ -z "${caller}" || "${caller}" == "root" ]]; then
    return 1
  fi

  caller_home="$(getent passwd "${caller}" | cut -d: -f6)"
  [[ -n "${caller_home}" && -d "${caller_home}/.ssh" ]] || return 1

  shopt -s nullglob
  for key_file in "${caller_home}/.ssh/"*.pub; do
    if install_public_key_content "$(<"${key_file}")"; then
      copied=1
    fi
  done
  shopt -u nullglob

  [[ "${copied}" -eq 1 ]]
}

ensure_bootstrap_ssh_access() {
  local installed=0

  if [[ -n "${ADMIN_SSH_KEY_FILE}" ]]; then
    [[ -f "${ADMIN_SSH_KEY_FILE}" ]] || die "ADMIN_SSH_KEY_FILE not found: ${ADMIN_SSH_KEY_FILE}"
    if install_public_key_content "$(<"${ADMIN_SSH_KEY_FILE}")"; then
      installed=1
      BOOTSTRAP_KEY_SOURCE="admin_ssh_key_file"
    fi
  fi

  if [[ -n "${ADMIN_SSH_KEY}" ]]; then
    if install_public_key_content "${ADMIN_SSH_KEY}"; then
      installed=1
      BOOTSTRAP_KEY_SOURCE="admin_ssh_key"
    fi
  fi

  if bool_true "${COPY_CALLER_SSH_KEYS}"; then
    if copy_caller_public_keys; then
      installed=1
      BOOTSTRAP_KEY_SOURCE="copied_caller_keys"
    fi
  fi

  if [[ "${installed}" -eq 1 ]]; then
    log "Installed SSH access for ${DESKTOP_USER} via ${BOOTSTRAP_KEY_SOURCE}."
    return
  fi

  warn "No SSH public keys were installed for ${DESKTOP_USER}; bootstrap will rely on the generated password."
}

configure_xrdp_files() {
  log "Configuring XRDP."

  backup_file /etc/xrdp/xrdp.ini
  backup_file /etc/xrdp/sesman.ini
  backup_file /etc/xrdp/startwm.sh
  backup_file /etc/xrdp/reconnectwm.sh

  if ini_set /etc/xrdp/xrdp.ini "Globals" "port" "${RDP_PORT_CONFIG}"; then XRDP_CHANGED=1; fi
  if ini_set /etc/xrdp/xrdp.ini "Globals" "address" "${RDP_BIND_ADDR}"; then XRDP_CHANGED=1; fi
  if ini_set /etc/xrdp/xrdp.ini "Globals" "use_vsock" "false"; then XRDP_CHANGED=1; fi
  if ini_set /etc/xrdp/xrdp.ini "Globals" "security_layer" "tls"; then XRDP_CHANGED=1; fi
  if ini_set /etc/xrdp/xrdp.ini "Globals" "crypt_level" "high"; then XRDP_CHANGED=1; fi
  if ini_set /etc/xrdp/xrdp.ini "Globals" "ssl_protocols" "TLSv1.2,TLSv1.3"; then XRDP_CHANGED=1; fi

  if ini_set /etc/xrdp/sesman.ini "Globals" "ReconnectScript" "reconnectwm.sh"; then SESMAN_CHANGED=1; fi
  if ini_set /etc/xrdp/sesman.ini "Globals" "AlwaysRunReconnect" "yes"; then SESMAN_CHANGED=1; fi
  if ini_set /etc/xrdp/sesman.ini "Security" "AllowRootLogin" "false"; then SESMAN_CHANGED=1; fi
  if ini_set /etc/xrdp/sesman.ini "Security" "MaxLoginRetry" "4"; then SESMAN_CHANGED=1; fi
  if ini_set /etc/xrdp/sesman.ini "Security" "RestrictOutboundClipboard" "none"; then SESMAN_CHANGED=1; fi
  if ini_set /etc/xrdp/sesman.ini "Security" "RestrictInboundClipboard" "none"; then SESMAN_CHANGED=1; fi
  if ini_set /etc/xrdp/sesman.ini "Sessions" "Policy" "UB"; then SESMAN_CHANGED=1; fi
  if ini_set /etc/xrdp/sesman.ini "Sessions" "MaxSessions" "1"; then SESMAN_CHANGED=1; fi
  if ini_set /etc/xrdp/sesman.ini "Sessions" "KillDisconnected" "false"; then SESMAN_CHANGED=1; fi
  if ini_set /etc/xrdp/sesman.ini "Sessions" "DisconnectedTimeLimit" "0"; then SESMAN_CHANGED=1; fi
  if ini_set /etc/xrdp/sesman.ini "Sessions" "IdleTimeLimit" "0"; then SESMAN_CHANGED=1; fi

  if ensure_group_membership "xrdp" "ssl-cert"; then
    XRDP_CHANGED=1
  fi

  chown root:root /etc/xrdp/xrdp.ini /etc/xrdp/sesman.ini
  chmod 0644 /etc/xrdp/xrdp.ini /etc/xrdp/sesman.ini

  if [[ -f /etc/xrdp/key.pem ]]; then
    chgrp ssl-cert /etc/xrdp/key.pem
    chmod 0640 /etc/xrdp/key.pem
  fi
  if [[ -f /etc/xrdp/cert.pem ]]; then
    chmod 0644 /etc/xrdp/cert.pem
  fi

  if write_file_if_changed /etc/xrdp/startwm.sh 0755 root root <<'EOF'
#!/bin/sh
if [ -r /etc/default/locale ]; then
  . /etc/default/locale
  export LANG LANGUAGE
fi
unset DBUS_SESSION_BUS_ADDRESS
unset XDG_RUNTIME_DIR
if command -v xset >/dev/null 2>&1; then
  xset s off
  xset s noblank
  xset -dpms
fi
exec startxfce4
EOF
  then
    XRDP_CHANGED=1
  fi

  if write_file_if_changed /etc/xrdp/reconnectwm.sh 0755 root root <<'EOF'
#!/bin/sh
if command -v xset >/dev/null 2>&1; then
  xset s off || true
  xset s noblank || true
  xset -dpms || true
fi
exit 0
EOF
  then
    SESMAN_CHANGED=1
  fi
}

configure_desktop_user_files() {
  local xfce_config_dir="${TARGET_HOME}/.config/xfce4/xfconf/xfce-perchannel-xml"
  local autostart_dir="${TARGET_HOME}/.config/autostart"
  local terminal_config_dir="${TARGET_HOME}/.config/xfce4/terminal"

  ensure_directory "${TARGET_HOME}/.config" 0755 "${DESKTOP_USER}" "${DESKTOP_USER}"
  ensure_directory "$(dirname "${xfce_config_dir}")" 0755 "${DESKTOP_USER}" "${DESKTOP_USER}"
  ensure_directory "${xfce_config_dir}" 0755 "${DESKTOP_USER}" "${DESKTOP_USER}"
  ensure_directory "${autostart_dir}" 0755 "${DESKTOP_USER}" "${DESKTOP_USER}"
  ensure_directory "${terminal_config_dir}" 0755 "${DESKTOP_USER}" "${DESKTOP_USER}"

  write_file_if_changed "${TARGET_HOME}/.xsession" 0644 "${DESKTOP_USER}" "${DESKTOP_USER}" <<'EOF'
startxfce4
EOF

  write_file_if_changed "${xfce_config_dir}/xfce4-power-manager.xml" 0644 "${DESKTOP_USER}" "${DESKTOP_USER}" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-power-manager" version="1.0">
  <property name="inactivity-on-ac" type="int" value="0"/>
  <property name="inactivity-on-battery" type="int" value="0"/>
  <property name="logind-handle-lid-switch" type="bool" value="false"/>
  <property name="logind-handle-suspend-switch" type="bool" value="false"/>
  <property name="dpms-enabled" type="bool" value="false"/>
</channel>
EOF

  write_file_if_changed "${xfce_config_dir}/xfce4-screensaver.xml" 0644 "${DESKTOP_USER}" "${DESKTOP_USER}" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-screensaver" version="1.0">
  <property name="lock" type="empty">
    <property name="enabled" type="bool" value="false"/>
    <property name="lock-on-suspend" type="bool" value="false"/>
  </property>
  <property name="saver" type="empty">
    <property name="enabled" type="bool" value="false"/>
    <property name="idle-activation-enabled" type="bool" value="false"/>
    <property name="timeout" type="int" value="0"/>
    <property name="mode" type="int" value="0"/>
    <property name="lock-delay" type="int" value="0"/>
  </property>
</channel>
EOF

  write_file_if_changed "${autostart_dir}/xfce4-screensaver.desktop" 0644 "${DESKTOP_USER}" "${DESKTOP_USER}" <<'EOF'
[Desktop Entry]
Type=Application
Name=XFCE Screen Saver
Exec=xfce4-screensaver
Hidden=true
X-GNOME-Autostart-enabled=false
EOF

  write_file_if_changed "${autostart_dir}/light-locker.desktop" 0644 "${DESKTOP_USER}" "${DESKTOP_USER}" <<'EOF'
[Desktop Entry]
Type=Application
Name=Light Locker
Exec=light-locker
Hidden=true
X-GNOME-Autostart-enabled=false
EOF

  touch "${terminal_config_dir}/terminalrc"
  chmod 0644 "${terminal_config_dir}/terminalrc"
  chown "${DESKTOP_USER}:${DESKTOP_USER}" "${terminal_config_dir}/terminalrc"
}

configure_sleep_settings() {
  backup_file /etc/systemd/logind.conf
  if ini_set /etc/systemd/logind.conf "Login" "HandleLidSwitch" "ignore"; then LOGIND_CHANGED=1; fi
  if ini_set /etc/systemd/logind.conf "Login" "HandleLidSwitchDocked" "ignore"; then LOGIND_CHANGED=1; fi
  if ini_set /etc/systemd/logind.conf "Login" "HandleSuspendKey" "ignore"; then LOGIND_CHANGED=1; fi
  if ini_set /etc/systemd/logind.conf "Login" "HandleHibernateKey" "ignore"; then LOGIND_CHANGED=1; fi
  if ini_set /etc/systemd/logind.conf "Login" "HandleLidSwitchExternalPower" "ignore"; then LOGIND_CHANGED=1; fi

  if [[ -f /etc/UPower/UPower.conf ]]; then
    backup_file /etc/UPower/UPower.conf
    if ini_set /etc/UPower/UPower.conf "Sleep" "AllowSuspend" "false"; then UPOWER_CHANGED=1; fi
    if ini_set /etc/UPower/UPower.conf "Sleep" "AllowHibernate" "false"; then UPOWER_CHANGED=1; fi
  fi

  systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target >/dev/null
}

configure_fail2ban() {
  ensure_directory /etc/fail2ban/jail.d 0755 root root
  if write_file_if_changed /etc/fail2ban/jail.d/sshd-local.conf 0644 root root <<EOF
[sshd]
enabled = true
maxretry = 5
findtime = 10m
bantime = 1h
port = ${SSH_PORT}
EOF
  then
    FAIL2BAN_CHANGED=1
  fi
}

configure_firewall_if_requested() {
  if ! bool_true "${ENABLE_UFW}"; then
    return
  fi

  if ensure_packages_installed ufw; then
    log "Installed ufw."
  fi

  ufw default deny incoming
  ufw default allow outgoing
  ufw allow "${SSH_PORT}/tcp"
  warn "If this server hosts web traffic, allow 80/443 before enabling UFW."
  ufw --force enable
}

restart_changed_services() {
  systemctl enable --now xrdp >/dev/null

  if systemctl list-unit-files xrdp-sesman.service >/dev/null 2>&1; then
    systemctl start xrdp-sesman >/dev/null 2>&1 || true
  fi

  if [[ "${SESMAN_CHANGED}" -eq 1 ]]; then
    log "Restarting xrdp-sesman."
    systemctl restart xrdp-sesman
  fi

  if [[ "${XRDP_CHANGED}" -eq 1 || "${SESMAN_CHANGED}" -eq 1 ]] || ! systemctl is-active --quiet xrdp; then
    log "Restarting xrdp."
    systemctl restart xrdp
  fi

  if [[ "${LOGIND_CHANGED}" -eq 1 ]]; then
    systemctl restart systemd-logind
  fi

  if [[ "${UPOWER_CHANGED}" -eq 1 ]] && systemctl list-unit-files upower.service >/dev/null 2>&1; then
    systemctl restart upower
  fi

  systemctl enable --now fail2ban >/dev/null
  if [[ "${FAIL2BAN_CHANGED}" -eq 1 ]]; then
    systemctl restart fail2ban
  fi

  wait_for_xrdp "${RDP_PORT}" "${RDP_BIND_ADDR}" || die "XRDP is not listening on ${RDP_BIND_ADDR}:${RDP_PORT}."
}

session_records_for_user() {
  local target_user="$1"
  local records=()

  if command_exists xrdp-sesadmin; then
    mapfile -t records < <(xrdp-sesadmin -c=list 2>/dev/null | awk -v target="${target_user}" '
      function flush_record() {
        if (sid != "" && user == target) {
          print sid "\t" display "\t" state "\t" "xrdp-sesadmin"
        }
      }
      /^Session ID:/ {
        flush_record()
        sid = $3
        display = ""
        user = ""
        state = "unknown"
        next
      }
      /^\tDisplay:/ {
        display = $2
        next
      }
      /^\tUser:/ {
        user = $2
        next
      }
      /^\tConnection state:/ {
        state = $3
        next
      }
      END {
        flush_record()
      }
    ')
    if [[ ${#records[@]} -gt 0 ]]; then
      printf '%s\n' "${records[@]}"
      return 0
    fi
  fi

  mapfile -t records < <(loginctl_records_for_user "${target_user}")
  if [[ ${#records[@]} -gt 0 ]]; then
    printf '%s\n' "${records[@]}"
    return 0
  fi

  process_records_for_user "${target_user}"
}

normalize_session_state() {
  local raw_state="${1:-unknown}"

  case "${raw_state,,}" in
    connected|active|yes)
      printf 'connected'
      ;;
    disconnected|closing|closing*) 
      printf 'disconnected'
      ;;
    no|inactive)
      printf 'disconnected'
      ;;
    *)
      printf 'unknown'
      ;;
  esac
}

session_sort_key() {
  local sid="$1"
  local display="$2"

  if [[ "${sid}" =~ ^c([0-9]+)$ ]]; then
    printf '%08d\n' "${BASH_REMATCH[1]}"
    return
  fi
  if [[ "${sid}" =~ ^display-([0-9]+)$ ]]; then
    printf '%08d\n' "${BASH_REMATCH[1]}"
    return
  fi
  if [[ "${sid}" =~ ^[0-9]+$ ]]; then
    printf '%08d\n' "${sid}"
    return
  fi
  if [[ "${display}" =~ ^:([0-9]+)$ ]]; then
    printf '%08d\n' "${BASH_REMATCH[1]}"
    return
  fi

  printf '%s\n' "${sid}"
}

find_xrdp_display_for_leader() {
  local leader_pid="$1"

  [[ -n "${leader_pid}" && "${leader_pid}" =~ ^[0-9]+$ ]] || return 1

  ps -eo pid=,ppid=,args= | awk -v leader="${leader_pid}" '
    {
      pid = $1
      ppid = $2
      $1 = ""
      $2 = ""
      sub(/^[[:space:]]+/, "", $0)
      parent[pid] = ppid
      cmd[pid] = $0
    }
    END {
      desc[leader] = 1
      changed = 1
      while (changed) {
        changed = 0
        for (pid in parent) {
          if (desc[parent[pid]] && !desc[pid]) {
            desc[pid] = 1
            changed = 1
          }
        }
      }

      for (pid in desc) {
        if (cmd[pid] ~ /\/Xorg .*xrdp\/xorg\.conf/) {
          if (match(cmd[pid], /:[0-9]+/)) {
            print substr(cmd[pid], RSTART, RLENGTH)
            exit
          }
        }
      }
    }
  '
}

loginctl_records_for_user() {
  local target_user="$1"
  local sid
  local uid
  local listed_user
  local line
  local leader=""
  local active=""
  local state=""
  local remote=""
  local service=""
  local display=""
  local bucket=""

  if ! command_exists loginctl; then
    return 0
  fi

  while read -r sid uid listed_user _; do
    [[ -n "${sid:-}" && "${listed_user:-}" == "${target_user}" ]] || continue

    leader=""
    active=""
    state=""
    remote=""
    service=""

    while IFS= read -r line; do
      case "${line}" in
        Leader=*) leader="${line#Leader=}" ;;
        Active=*) active="${line#Active=}" ;;
        State=*) state="${line#State=}" ;;
        Remote=*) remote="${line#Remote=}" ;;
        Service=*) service="${line#Service=}" ;;
      esac
    done < <(loginctl show-session "${sid}" -p Leader -p Active -p State -p Remote -p Service 2>/dev/null || true)

    [[ -n "${leader}" || -n "${active}" || -n "${state}" || -n "${remote}" || -n "${service}" ]] || continue

    if [[ "${remote,,}" == "yes" && "${service}" == "sshd" ]]; then
      continue
    fi

    display="$(find_xrdp_display_for_leader "${leader}" || true)"

    if [[ -z "${display}" && "${remote,,}" != "yes" && "${service}" != "xrdp-sesman" ]]; then
      continue
    fi

    if [[ "${active,,}" == "yes" ]]; then
      bucket="connected"
    elif [[ "${active,,}" == "no" ]]; then
      bucket="disconnected"
    else
      bucket="$(normalize_session_state "${state}")"
    fi

    printf '%s\t%s\t%s\t%s\n' "${sid}" "${display:-unknown}" "${bucket}" "loginctl"
  done < <(loginctl list-sessions --no-legend 2>/dev/null || true)
}

process_records_for_user() {
  local target_user="$1"

  ps -u "${target_user}" -o pid=,command= | awk '
    $0 ~ /\/Xorg .*xrdp\/xorg\.conf/ {
      pid = $1
      if (match($0, /:[0-9]+/)) {
        display = substr($0, RSTART, RLENGTH)
        gsub(/^:/, "", display)
        print "display-" display "\t:" display "\tunknown\tps"
      }
    }
  '
}

service_status() {
  local service="$1"
  if systemctl is-active --quiet "${service}"; then
    printf 'active'
  else
    printf 'inactive'
  fi
}

show_status() {
  local records=()
  local record
  local total=0
  local connected=0
  local disconnected=0
  local unknown=0
  local source=""

  printf 'Target user: %s\n' "${DESKTOP_USER}"
  printf 'xrdp: %s\n' "$(service_status xrdp)"
  if systemctl list-unit-files xrdp-sesman.service >/dev/null 2>&1; then
    printf 'xrdp-sesman: %s\n' "$(service_status xrdp-sesman)"
  fi
  if systemctl list-unit-files fail2ban.service >/dev/null 2>&1; then
    printf 'fail2ban: %s\n' "$(service_status fail2ban)"
  fi

  if wait_for_xrdp "${RDP_PORT}" "${RDP_BIND_ADDR}" 1; then
    printf 'listener: %s:%s\n' "${RDP_BIND_ADDR}" "${RDP_PORT}"
  else
    printf 'listener: not-ready\n'
  fi

  mapfile -t records < <(session_records_for_user "${DESKTOP_USER}")
  if [[ ${#records[@]} -eq 0 ]]; then
    printf 'sessions: none for %s\n' "${DESKTOP_USER}"
    return 0
  fi

  printf 'sessions:\n'
  for record in "${records[@]}"; do
    total=$((total + 1))
    source="$(awk -F '\t' '{print $4}' <<<"${record}")"
    case "$(awk -F '\t' '{print $3}' <<<"${record}")" in
      connected) connected=$((connected + 1)) ;;
      disconnected) disconnected=$((disconnected + 1)) ;;
      *) unknown=$((unknown + 1)) ;;
    esac
    printf '  sid=%s display=%s state=%s\n' \
      "${record%%$'\t'*}" \
      "$(awk -F '\t' '{print $2}' <<<"${record}")" \
      "$(awk -F '\t' '{print $3}' <<<"${record}")"
    printf '  source=%s\n' "${source}"
  done
  printf 'session-summary: total=%s connected=%s disconnected=%s unknown=%s\n' "${total}" "${connected}" "${disconnected}" "${unknown}"
}

collect_pids_for_display() {
  local display="$1"
  local user="$2"
  local -n pids_ref="$3"
  local pid

  while IFS= read -r pid; do
    [[ -n "${pid}" ]] || continue
    pids_ref["${pid}"]=1
  done < <(ps eww -u "${user}" -o pid=,command= | awk -v disp="${display}" '
    $0 ~ ("(^|[[:space:]])DISPLAY=" disp "([[:space:]]|$)") { print $1 }
  ')

  while IFS= read -r pid; do
    [[ -n "${pid}" ]] || continue
    pids_ref["${pid}"]=1
  done < <(pgrep -f "Xorg ${display}( |$).*xrdp/xorg.conf" || true)
}

terminate_session_display() {
  local sid="$1"
  local display="$2"
  local user="$3"
  local warn_on_missing="${4:-true}"
  local -A pids=()
  local pid
  local remaining=()

  if [[ -z "${display}" || "${display}" == "unknown" ]]; then
    if bool_true "${warn_on_missing}"; then
      warn "No display information found for sid=${sid}; skipping process-tree cleanup."
    fi
    return 1
  fi

  collect_pids_for_display "${display}" "${user}" pids

  if [[ ${#pids[@]} -eq 0 ]]; then
    if bool_true "${warn_on_missing}"; then
      warn "No processes found for sid=${sid} display=${display}; nothing to kill."
    fi
    return 1
  fi

  log "Terminating XRDP session sid=${sid} display=${display} user=${user}"
  for pid in "${!pids[@]}"; do
    kill -TERM "${pid}" 2>/dev/null || true
  done
  sleep 3

  for pid in "${!pids[@]}"; do
    if kill -0 "${pid}" 2>/dev/null; then
      remaining+=("${pid}")
    fi
  done

  if [[ ${#remaining[@]} -gt 0 ]]; then
    warn "Escalating to SIGKILL for sid=${sid} display=${display}: ${remaining[*]}"
    kill -KILL "${remaining[@]}" 2>/dev/null || true
  fi

  return 0
}

terminate_all_xrdp_sessions() {
  local records=()
  local record
  local sid
  local display
  local source
  local cleaned=0

  mapfile -t records < <(session_records_for_user "${DESKTOP_USER}")

  if [[ ${#records[@]} -eq 0 ]]; then
    log "No XRDP sessions found for ${DESKTOP_USER}."
    return 0
  fi

  log "Terminating all XRDP sessions for ${DESKTOP_USER} before service restart."

  for record in "${records[@]}"; do
    sid="${record%%$'\t'*}"
    display="$(awk -F '\t' '{print $2}' <<<"${record}")"
    source="$(awk -F '\t' '{print $4}' <<<"${record}")"

    if [[ "${source}" == "loginctl" ]]; then
      log "Terminating loginctl XRDP session sid=${sid} for ${DESKTOP_USER}"
      loginctl terminate-session "${sid}" >/dev/null 2>&1 || true
      sleep 2
    fi

    if terminate_session_display "${sid}" "${display}" "${DESKTOP_USER}" false; then
      cleaned=$((cleaned + 1))
    fi
  done

  log "Requested shutdown for ${#records[@]} XRDP session record(s); killed ${cleaned} display-backed process tree(s)."
}

cleanup_extra_sessions_keep_newest() {
  local records=()
  local record
  local sid
  local display
  local state
  local source
  local keep_sid=""
  local keep_display=""
  local newest_sid=""
  local newest_sort_key=""
  local sort_key=""
  local cleaned=0

  mapfile -t records < <(session_records_for_user "${DESKTOP_USER}")

  if [[ ${#records[@]} -le 1 ]]; then
    log "No extra XRDP sessions found for ${DESKTOP_USER}."
    return 0
  fi

  for record in "${records[@]}"; do
    sid="${record%%$'\t'*}"
    display="$(awk -F '\t' '{print $2}' <<<"${record}")"
    sort_key="$(session_sort_key "${sid}" "${display}")"
    if [[ -z "${newest_sid}" || "${sort_key}" > "${newest_sort_key}" ]]; then
      newest_sid="${sid}"
      newest_sort_key="${sort_key}"
      keep_display="${display}"
    fi
  done

  keep_sid="${newest_sid}"
  log "Preserving newest XRDP session sid=${keep_sid} display=${keep_display} for ${DESKTOP_USER}; terminating older sessions."

  for record in "${records[@]}"; do
    sid="${record%%$'\t'*}"
    display="$(awk -F '\t' '{print $2}' <<<"${record}")"
    state="$(awk -F '\t' '{print $3}' <<<"${record}")"
    source="$(awk -F '\t' '{print $4}' <<<"${record}")"

    if [[ "${sid}" == "${keep_sid}" ]]; then
      continue
    fi

    if [[ "${source}" == "loginctl" ]]; then
      log "Terminating older loginctl XRDP session sid=${sid} state=${state} for ${DESKTOP_USER}"
      loginctl terminate-session "${sid}" >/dev/null 2>&1 || true
      sleep 2
    fi

    if terminate_session_display "${sid}" "${display}" "${DESKTOP_USER}" true; then
      cleaned=$((cleaned + 1))
    fi
  done

  if [[ "${cleaned}" -eq 0 ]]; then
    log "No extra XRDP sessions required cleanup for ${DESKTOP_USER}."
  else
    log "Cleaned ${cleaned} older XRDP session(s) for ${DESKTOP_USER}."
  fi
}

restart_xrdp_services() {
  local mode="$1"

  require_root
  ensure_target_user_resolved

  case "${mode}" in
    safe)
      log "Performing clean XRDP restart. Existing XRDP desktops for ${DESKTOP_USER} will be terminated."
      terminate_all_xrdp_sessions
      systemctl restart xrdp-sesman xrdp
      ;;
    full)
      warn "Full restart is equivalent to the clean XRDP reset on this packaged Ubuntu setup."
      terminate_all_xrdp_sessions
      systemctl restart xrdp-sesman
      systemctl restart xrdp
      ;;
    *)
      die "Unsupported restart mode: ${mode}"
      ;;
  esac

  wait_for_xrdp "${RDP_PORT}" "${RDP_BIND_ADDR}" || die "XRDP did not come back after restart."

  if bool_true "${AUTO_CLEANUP_DUPLICATES}"; then
    cleanup_extra_sessions_keep_newest
  fi

  show_status
}

verify_or_warn() {
  local description="$1"
  local cmd="$2"
  if eval "${cmd}"; then
    printf 'PASS: %s\n' "${description}"
  else
    printf 'FAIL: %s\n' "${description}"
    return 1
  fi
}

show_connection_instructions() {
  cat <<EOF

Connection commands:
1) SSH tunnel:
   ssh -N -L ${LOCAL_TUNNEL_PORT}:127.0.0.1:${RDP_PORT} ${DESKTOP_USER}@${OUTPUT_SERVER_IP}

2) RDP client:
   xfreerdp /v:127.0.0.1:${LOCAL_TUNNEL_PORT} /u:${DESKTOP_USER} +clipboard +auto-reconnect /dynamic-resolution /cert:ignore
EOF

  if [[ "${BOOTSTRAP_PASSWORD_WAS_GENERATED}" -eq 1 ]]; then
    cat <<EOF

Bootstrap password generated for ${DESKTOP_USER}:
  ${BOOTSTRAP_PASSWORD}
Stored at:
  ${BOOTSTRAP_PASSWORD_FILE}
EOF
  elif [[ "${BOOTSTRAP_PASSWORD_SOURCE}" == "stored" ]]; then
    cat <<EOF

Bootstrap password file for ${DESKTOP_USER}:
  ${BOOTSTRAP_PASSWORD_FILE}
EOF
  fi
}

setup_action() {
  require_root
  ensure_target_user_resolved

  if ensure_packages_installed xrdp xorgxrdp xfce4 xfce4-goodies fail2ban dbus-x11 x11-xserver-utils openssl; then
    log "Core XRDP packages installed."
    XRDP_CHANGED=1
    SESMAN_CHANGED=1
    FAIL2BAN_CHANGED=1
  fi

  configure_firewall_if_requested
  ensure_desktop_user
  ensure_bootstrap_ssh_access
  configure_xrdp_files
  configure_desktop_user_files
  configure_sleep_settings
  configure_fail2ban
  restart_changed_services
  show_status
  show_connection_instructions
}

verify_action() {
  local failed=0

  require_root
  ensure_target_user_resolved

  verify_or_warn "xrdp package installed" "dpkg -s xrdp >/dev/null 2>&1" || failed=1
  verify_or_warn "xorgxrdp package installed" "dpkg -s xorgxrdp >/dev/null 2>&1" || failed=1
  verify_or_warn "xfce4 package installed" "dpkg -s xfce4 >/dev/null 2>&1" || failed=1
  verify_or_warn "xrdp service active" "systemctl is-active --quiet xrdp" || failed=1
  verify_or_warn "xrdp-sesman service active" "systemctl is-active --quiet xrdp-sesman" || failed=1
  verify_or_warn "XRDP listener ready" "wait_for_xrdp '${RDP_PORT}' '${RDP_BIND_ADDR}' 1" || failed=1
  verify_or_warn "Target user exists" "id '${DESKTOP_USER}' >/dev/null 2>&1" || failed=1
  verify_or_warn "XRDP policy set to UB" "[[ \"\$(ini_get /etc/xrdp/sesman.ini Sessions Policy)\" == \"UB\" ]]" || failed=1
  verify_or_warn "XRDP MaxSessions set to 1" "[[ \"\$(ini_get /etc/xrdp/sesman.ini Sessions MaxSessions)\" == \"1\" ]]" || failed=1
  verify_or_warn "Clipboard inbound unrestricted" "[[ \"\$(ini_get /etc/xrdp/sesman.ini Security RestrictInboundClipboard)\" == \"none\" ]]" || failed=1
  verify_or_warn "Clipboard outbound unrestricted" "[[ \"\$(ini_get /etc/xrdp/sesman.ini Security RestrictOutboundClipboard)\" == \"none\" ]]" || failed=1
  verify_or_warn "Reconnect script configured" "[[ \"\$(ini_get /etc/xrdp/sesman.ini Globals ReconnectScript)\" == \"reconnectwm.sh\" ]]" || failed=1
  verify_or_warn "Startwm launches XFCE" "grep -Fqx 'exec startxfce4' /etc/xrdp/startwm.sh" || failed=1

  show_status
  show_connection_instructions

  [[ "${failed}" -eq 0 ]]
}

main() {
  parse_args "$@"

  case "${ACTION}" in
    setup)
      setup_action
      ;;
    status)
      require_root
      ensure_target_user_resolved
      show_status
      ;;
    cleanup)
      require_root
      ensure_target_user_resolved
      cleanup_extra_sessions_keep_newest
      show_status
      ;;
    safe-restart)
      if bool_true "${WITH_SESMAN_RESTART}"; then
        restart_xrdp_services full
      else
        restart_xrdp_services safe
      fi
      ;;
    restart-all)
      restart_xrdp_services full
      ;;
    verify)
      if ! verify_action; then
        exit 1
      fi
      ;;
    help)
      usage
      ;;
  esac
}

main "$@"
