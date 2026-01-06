#!/usr/bin/env bash
set -euo pipefail

# XRDP + XFCE private setup for Ubuntu 22.04.
# Access is via SSH tunnel; XRDP is bound to localhost and not exposed publicly.
# Run as root. Set ADMIN_USER to an existing sudo-enabled user.

RDP_PORT="${RDP_PORT:-43389}"
LOCAL_TUNNEL_PORT="${LOCAL_TUNNEL_PORT:-13389}"
DEFAULT_ADMIN_USER="${SUDO_USER:-}"
if [ -z "${DEFAULT_ADMIN_USER}" ] || [ "${DEFAULT_ADMIN_USER}" = "root" ]; then
  DEFAULT_ADMIN_USER="admin"
fi
ADMIN_USER="${ADMIN_USER:-${DEFAULT_ADMIN_USER}}"
ADMIN_SSH_KEY="${ADMIN_SSH_KEY:-ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDioS78RQG+/E5RwMxXi1XOcSig+MtTS2unXpKKZFyEK loldlm1@gmail.com}"
SSH_PORT="${SSH_PORT:-22}"
ENABLE_UFW="${ENABLE_UFW:-false}"
OUTPUT_SERVER_IP="${SERVER_IP:-}"
if [ -z "${OUTPUT_SERVER_IP}" ] && [ -n "${SSH_CONNECTION:-}" ]; then
  OUTPUT_SERVER_IP="$(echo "${SSH_CONNECTION}" | awk '{print $3}')"
fi
if [ -z "${OUTPUT_SERVER_IP}" ]; then
  OUTPUT_SERVER_IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
fi
if [ -z "${OUTPUT_SERVER_IP}" ]; then
  OUTPUT_SERVER_IP="<server_ip>"
fi

if [ "$(id -u)" -ne 0 ]; then
  echo "Run as root: sudo ADMIN_USER=<user> $0"
  exit 1
fi

if [ -z "${ADMIN_USER}" ]; then
  echo "Set ADMIN_USER to a non-root admin account (e.g. sudo ADMIN_USER=admin $0)"
  exit 1
fi

if [ "${ADMIN_USER}" = "root" ]; then
  echo "ADMIN_USER must be a non-root account with sudo access."
  exit 1
fi

if ! id "${ADMIN_USER}" >/dev/null 2>&1; then
  echo "Creating admin user: ${ADMIN_USER}"
  if getent group "${ADMIN_USER}" >/dev/null 2>&1; then
    useradd -m -s /bin/bash -g "${ADMIN_USER}" "${ADMIN_USER}"
  else
    useradd -m -s /bin/bash -U "${ADMIN_USER}"
  fi
  usermod -aG sudo "${ADMIN_USER}"
fi

ADMIN_HOME="$(getent passwd "${ADMIN_USER}" | cut -d: -f6)"
if [ -z "${ADMIN_HOME}" ] || [ ! -d "${ADMIN_HOME}" ]; then
  echo "Could not resolve home directory for ${ADMIN_USER}."
  exit 1
fi

if [ -n "${ADMIN_SSH_KEY}" ]; then
  ADMIN_SSH_DIR="${ADMIN_HOME}/.ssh"
  ADMIN_AUTH_KEYS="${ADMIN_SSH_DIR}/authorized_keys"
  mkdir -p "${ADMIN_SSH_DIR}"
  chmod 0700 "${ADMIN_SSH_DIR}"
  touch "${ADMIN_AUTH_KEYS}"
  chmod 0600 "${ADMIN_AUTH_KEYS}"
  if ! grep -Fqx "${ADMIN_SSH_KEY}" "${ADMIN_AUTH_KEYS}"; then
    echo "${ADMIN_SSH_KEY}" >> "${ADMIN_AUTH_KEYS}"
  fi
  chown -R "${ADMIN_USER}:${ADMIN_USER}" "${ADMIN_SSH_DIR}"
else
  echo "ADMIN_SSH_KEY is empty; skipping SSH key install."
fi

backup_file() {
  local file="$1"
  if [ -f "$file" ] && [ ! -f "${file}.bak" ]; then
    cp "$file" "${file}.bak"
  fi
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

  tmp="$(mktemp)"
  mode="$(stat -c '%a' "$file" 2>/dev/null || true)"
  owner="$(stat -c '%u' "$file" 2>/dev/null || true)"
  group="$(stat -c '%g' "$file" 2>/dev/null || true)"
  awk -v section="$section" -v key="$key" -v value="$value" '
    BEGIN { in_section=0; inserted=0 }
    /^[[:space:]]*\[.*\][[:space:]]*$/ {
      if (in_section && !inserted) {
        print key"="value
        inserted=1
      }
      in_section = ($0 ~ "\\["section"\\]")
      print
      next
    }
    {
      if (in_section && $0 ~ "^[[:space:]]*"key"[[:space:]]*=") {
        next
      }
      print
    }
    END {
      if (in_section && !inserted) print key"="value
    }
  ' "$file" > "$tmp"
  mv "$tmp" "$file"
  if [ -n "${mode}" ]; then
    chmod "${mode}" "$file"
  fi
  if [ -n "${owner}" ] && [ -n "${group}" ]; then
    chown "${owner}:${group}" "$file"
  fi
}

wait_for_xrdp() {
  local port="$1"
  local tries=10
  local listen_addr=""
  local i

  for i in $(seq 1 "${tries}"); do
    listen_addr="$(ss -ltnp 2>/dev/null | awk -v p=":${port}" '$4 ~ p {print $4; exit}')"
    case "${listen_addr}" in
      127.0.0.1:*|[::1]:*) return 0 ;;
      "") sleep 1 ;;
      *) echo "XRDP is listening on ${listen_addr} (expected 127.0.0.1:${port})."; return 1 ;;
    esac
  done

  return 1
}

echo "Installing packages..."
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y xrdp xorgxrdp xfce4 xfce4-goodies fail2ban

if [ "${ENABLE_UFW}" = "true" ]; then
  apt-get install -y ufw
  ufw default deny incoming
  ufw default allow outgoing
  ufw allow "${SSH_PORT}/tcp"
  echo "If this server hosts web traffic, allow 80/443 before enabling UFW."
  ufw --force enable
fi

echo "Configuring XRDP..."
backup_file /etc/xrdp/xrdp.ini
backup_file /etc/xrdp/sesman.ini
backup_file /etc/xrdp/startwm.sh

ini_set /etc/xrdp/xrdp.ini "Globals" "port" "${RDP_PORT}"
ini_set /etc/xrdp/xrdp.ini "Globals" "address" "127.0.0.1"
ini_set /etc/xrdp/xrdp.ini "Globals" "use_vsock" "false"
ini_set /etc/xrdp/xrdp.ini "Globals" "security_layer" "tls"
ini_set /etc/xrdp/xrdp.ini "Globals" "crypt_level" "high"
ini_set /etc/xrdp/xrdp.ini "Globals" "ssl_protocols" "TLSv1.2,TLSv1.3"

ini_set /etc/xrdp/sesman.ini "Security" "AllowRootLogin" "false"
ini_set /etc/xrdp/sesman.ini "Security" "MaxLoginRetry" "4"

usermod -a -G ssl-cert xrdp

chown root:root /etc/xrdp/xrdp.ini /etc/xrdp/sesman.ini
chmod 0644 /etc/xrdp/xrdp.ini /etc/xrdp/sesman.ini
if [ -f /etc/xrdp/key.pem ]; then
  chgrp ssl-cert /etc/xrdp/key.pem
  chmod 0640 /etc/xrdp/key.pem
fi
if [ -f /etc/xrdp/cert.pem ]; then
  chmod 0644 /etc/xrdp/cert.pem
fi

cat > /etc/xrdp/startwm.sh <<'EOF'
#!/bin/sh
if [ -r /etc/default/locale ]; then
  . /etc/default/locale
  export LANG LANGUAGE
fi
unset DBUS_SESSION_BUS_ADDRESS
unset XDG_RUNTIME_DIR
startxfce4
EOF
chmod 0755 /etc/xrdp/startwm.sh

echo "startxfce4" > "${ADMIN_HOME}/.xsession"
chown "${ADMIN_USER}:${ADMIN_USER}" "${ADMIN_HOME}/.xsession"

XFCE_CONFIG_DIR="${ADMIN_HOME}/.config/xfce4/xfconf/xfce-perchannel-xml"
mkdir -p "${XFCE_CONFIG_DIR}"
cat > "${XFCE_CONFIG_DIR}/xfce4-power-manager.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-power-manager" version="1.0">
  <property name="inactivity-on-ac" type="int" value="0"/>
  <property name="inactivity-on-battery" type="int" value="0"/>
  <property name="logind-handle-lid-switch" type="bool" value="false"/>
  <property name="logind-handle-suspend-switch" type="bool" value="false"/>
  <property name="dpms-enabled" type="bool" value="false"/>
</channel>
EOF
chown -R "${ADMIN_USER}:${ADMIN_USER}" "${ADMIN_HOME}/.config/xfce4"

echo "Disabling sleep/hibernate..."
backup_file /etc/systemd/logind.conf
ini_set /etc/systemd/logind.conf "Login" "HandleLidSwitch" "ignore"
ini_set /etc/systemd/logind.conf "Login" "HandleLidSwitchDocked" "ignore"
ini_set /etc/systemd/logind.conf "Login" "HandleSuspendKey" "ignore"
ini_set /etc/systemd/logind.conf "Login" "HandleHibernateKey" "ignore"
ini_set /etc/systemd/logind.conf "Login" "HandleLidSwitchExternalPower" "ignore"

backup_file /etc/UPower/UPower.conf
ini_set /etc/UPower/UPower.conf "Sleep" "AllowSuspend" "false"
ini_set /etc/UPower/UPower.conf "Sleep" "AllowHibernate" "false"

systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
systemctl restart systemd-logind
systemctl restart upower

echo "Configuring fail2ban (SSH)..."
mkdir -p /etc/fail2ban/jail.d
cat > /etc/fail2ban/jail.d/sshd-local.conf <<'EOF'
[sshd]
enabled = true
maxretry = 5
findtime = 10m
bantime = 1h
EOF
systemctl enable --now fail2ban

systemctl enable --now xrdp
if systemctl status xrdp-sesman >/dev/null 2>&1; then
  systemctl restart xrdp-sesman
fi
systemctl restart xrdp

if command -v ss >/dev/null 2>&1; then
  if ! wait_for_xrdp "${RDP_PORT}"; then
    echo "XRDP is not listening on 127.0.0.1:${RDP_PORT}."
    echo "Check: systemctl status xrdp"
    echo "Check: journalctl -u xrdp --no-pager -n 50"
    exit 1
  fi
else
  echo "ss not found; skipping XRDP port validation."
fi

cat <<EOF
Setup complete.

Make it executable and run on the server: chmod +x production_server_rdp_setup.sh then sudo bash production_server_rdp_setup.sh.

XRDP is bound to 127.0.0.1:${RDP_PORT} and is not publicly exposed.

Connect from your laptop:
1) Create SSH tunnel:
   ssh -N -L ${LOCAL_TUNNEL_PORT}:127.0.0.1:${RDP_PORT} ${ADMIN_USER}@${OUTPUT_SERVER_IP}
2) Start XRDP session:
   xfreerdp /v:127.0.0.1:${LOCAL_TUNNEL_PORT} /u:${ADMIN_USER}

Notes:
- Use sudo on the server for root tasks.
- If you enable UFW, allow 80/443 before enabling on production.
EOF
