#!/usr/bin/env bash
# setup.sh — Comprehensive Ubuntu setup (apt-only)
# - Installs core/desktop tools + VS Code (Microsoft repo)
# - Configures ddcutil/I2C permissions
# - Installs/Enables Brightness control using ddcutil GNOME extension from source
# - Sets pip: global.break-system-packages = true
# - Shows reboot/logout hints ONLY if required

set -Eeuo pipefail
SUDO=${SUDO:-sudo}

log()  { printf "\n\033[1;32m[+]\033[0m %s\n" "$*"; }
warn() { printf "\n\033[1;33m[!]\033[0m %s\n" "$*"; }
err()  { printf "\n\033[1;31m[x]\033[0m %s\n" "$*"; }

have_cmd() { command -v "$1" >/dev/null 2>&1; }

install_apt() {
  local pkg="$1"
  if dpkg -s "$pkg" >/dev/null 2>&1; then
    echo "  - $pkg already installed"
  else
    echo "  - installing $pkg"
    DEBIAN_FRONTEND=noninteractive \
      $SUDO apt-get install -y -o Dpkg::Use-Pty=0 "$pkg"
  fi
}

# -------------------- APT UPDATE & BASE PACKAGES ----------------------------
log "Updating apt lists"
$SUDO apt-get update -y -o Dpkg::Use-Pty=0

PKGS=(
  build-essential make
  curl wget ca-certificates gnupg jq unzip zip
  git
  python3 python3-pip
  zsh
  guake gnome-tweaks
  gnome-shell-extensions gnome-shell-extension-manager gnome-shell-extension-prefs
  dconf-cli
  ddcutil i2c-tools
  glib2.0-bin
  gettext
  libreoffice
)
log "Installing base packages"
for p in "${PKGS[@]}"; do install_apt "$p"; done

# pip: allow global installs (system-wide)
$SUDO python3 -m pip config set global.break-system-packages true

# -------------------- VS CODE (Microsoft repo, apt) -------------------------
if ! dpkg -s code >/dev/null 2>&1; then
  log "Adding Microsoft VS Code repo"
  wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
  $SUDO install -o root -g root -m 644 packages.microsoft.gpg /etc/apt/trusted.gpg.d/
  $SUDO sh -c 'echo "deb [arch=amd64,arm64,armhf] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
  rm -f packages.microsoft.gpg
  $SUDO apt-get update -y -o Dpkg::Use-Pty=0
  install_apt code
else
  echo "  - VS Code already installed"
fi

# -------------------- ZSH DEFAULT SHELL (optional) --------------------------
if have_cmd zsh && [ "${SHELL:-}" != "$(command -v zsh)" ]; then
  log "Setting zsh as default shell"
  chsh -s "$(command -v zsh)" "$USER" || warn "Couldn't change shell; log out/in to apply"
fi

# -------------------- DDCUTIL / I2C PERMISSIONS -----------------------------
log "Configuring ddcutil permissions"
# Was user already in i2c group? (for smart logout hint later)
BEFORE_I2C=$(id -nG | grep -qw i2c && echo yes || echo no)

$SUDO modprobe i2c-dev
echo i2c-dev | $SUDO tee /etc/modules-load.d/i2c.conf >/dev/null

# udev rules (packaged path; copy if present)
if [ -f /usr/share/ddcutil/data/60-ddcutil-i2c.rules ]; then
  $SUDO cp /usr/share/ddcutil/data/60-ddcutil-i2c.rules /etc/udev/rules.d/
fi

$SUDO groupadd --system i2c 2>/dev/null || true
$SUDO usermod -aG i2c "$USER"

# -------------------- GNOME EXTENSION: BRIGHTNESS (from source) ------------
# This extension's UUID varies across sources (github.io vs github.com).
# Try known candidates and pick the first that exists.
CANDIDATE_UUIDS=(
  "display-brightness-ddcutil@themightydeity.github.io"
  "display-brightness-ddcutil@themightydeity.github.com"
  "display-brightness-ddcutil@themightydeity"
)

have_cmd() { command -v "$1" >/dev/null 2>&1; }

ext_dir_user="$HOME/.local/share/gnome-shell/extensions"
ext_dir_sys="/usr/share/gnome-shell/extensions"

is_uuid_present() {
  local u="$1"
  gnome-extensions list 2>/dev/null | grep -qx "$u" && return 0
  [ -d "$ext_dir_user/$u" ] && return 0
  [ -d "$ext_dir_sys/$u" ] && return 0
  return 1
}

# Pick the installed UUID if any
INST_UUID=""
for u in "${CANDIDATE_UUIDS[@]}"; do
  if is_uuid_present "$u"; then
    INST_UUID="$u"
    break
  fi
done

EXT_CHANGED=0
STATE_BEFORE=""
if [ -n "$INST_UUID" ] && have_cmd gnome-extensions; then
  STATE_BEFORE="$(gnome-extensions info "$INST_UUID" 2>/dev/null | sed -n 's/^State: //p' || true)"
fi

if [ -n "$INST_UUID" ]; then
  log "GNOME extension already present: $INST_UUID"
  if have_cmd gnome-extensions && [ "${STATE_BEFORE:-}" != "ENABLED" ]; then
    gnome-extensions enable "$INST_UUID" || true
    EXT_CHANGED=1
  fi
else
  log "Building and installing GNOME extension from GitHub"
  WORKDIR="$(mktemp -d)"
  git clone --depth=1 https://github.com/daitj/gnome-display-brightness-ddcutil.git "$WORKDIR"
  ( cd "$WORKDIR" && make build && make install )
  rm -rf "$WORKDIR"

  # After install, discover the actual UUID from metadata.json
  NEW_UUID=""
  for p in "$ext_dir_user"/*/metadata.json "$ext_dir_sys"/*/metadata.json; do
    [ -f "$p" ] || continue
    if grep -q '"name"\s*:\s*"Brightness control using ddcutil"' "$p"; then
      NEW_UUID=$(grep -o '"uuid"\s*:\s*"[^"]*"' "$p" | sed 's/.*"uuid"\s*:\s*"\([^"]*\)".*/\1/')
      break
    fi
  done
  INST_UUID="${NEW_UUID:-display-brightness-ddcutil@themightydeity.github.io}"

  if have_cmd gnome-extensions; then
    gnome-extensions enable "$INST_UUID" || warn "Installed but couldn't enable; reload GNOME Shell"
  fi
  EXT_CHANGED=1
  echo "✔ Installed (source) & enabled: $INST_UUID"
fi


# -------------------- SYSTEM CLEANUP ----------------------------------------
log "Upgrading and cleaning"
DEBIAN_FRONTEND=noninteractive $SUDO apt-get dist-upgrade -y -o Dpkg::Use-Pty=0 || true
$SUDO apt-get autoremove -y -o Dpkg::Use-Pty=0 || true
$SUDO apt-get autoclean -y -o Dpkg::Use-Pty=0 || true

# -------------------- SMART HINTS (only if needed) --------------------------
NEED_LOGOUT=0
# After usermod, check group file membership (effective next session)
IN_GROUP_FILE=$(getent group i2c | grep -qw "$USER" && echo yes || echo no)
if [ "${BEFORE_I2C}" = "no" ] && [ "${IN_GROUP_FILE}" = "yes" ]; then
  NEED_LOGOUT=1
fi

if (( NEED_LOGOUT )); then
  echo "→ Log out/in so your session picks up the new 'i2c' group (for ddcutil)."
fi

if (( EXT_CHANGED )); then
  echo "→ Reload GNOME Shell to fully activate the extension:"
  echo "   - Wayland: Log out/in"
  echo "   - Xorg:    Press Alt+F2, type r, hit Enter"
fi

if (( !NEED_LOGOUT && !EXT_CHANGED )); then
  log "✅ Setup complete. No reboot/log out needed."
else
  log "✅ Setup complete."
fi

# Helpful tests:
#   ddcutil detect
#   ddcutil getvcp 10     # brightness read

