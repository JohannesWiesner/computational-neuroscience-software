#!/usr/bin/env bash
# Unified installer for computational-neuroscience-software
# Place vendor .deb or tarball installers into ./installation_files and run:
#   ./scripts/install.sh --list
#   sudo ./scripts/install.sh --all
#   sudo ./scripts/install.sh zotero
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_DIR="${REPO_ROOT}/installation_files"

# Logging helpers
info()  { printf "\033[1;34m[INFO]\033[0m %s\n" "$*"; }
warn()  { printf "\033[1;33m[WARN]\033[0m %s\n" "$*"; }
error() { printf "\033[1;31m[ERROR]\033[0m %s\n" "$*" >&2; }

# Ensure running as root when needed
require_root() {
  if [[ $EUID -ne 0 ]]; then
    error "This script requires root privileges. Re-run with sudo."
    exit 1
  fi
}

# Find a file in installation_files by glob (returns first match)
find_asset() {
  local pattern="$1"
  find "$INSTALL_DIR" -maxdepth 1 -type f -name "$pattern" | head -n1 || true
}

# Install .deb file if present
install_deb_from_assets() {
  local pattern="$1"
  local deb
  deb=$(find_asset "$pattern")
  if [[ -n "$deb" ]]; then
    info "Installing deb $deb"
    apt -y install "$deb"
    return 0
  else
    return 1
  fi
}

# Extract tarball to /opt/<name>
install_tarball_to_opt() {
  local pattern="$1"
  local dest="$2"
  local tb
  tb=$(find_asset "$pattern")
  if [[ -n "$tb" ]]; then
    info "Extracting $tb to /opt/$dest"
    mkdir -p "/opt/$dest"
    tar -xf "$tb" --strip-components=1 -C "/opt/$dest"
  else
    warn "No tarball matching '$pattern' in $INSTALL_DIR"
  fi
}

# Add apt repo with signed-by keyfile (expects keyring file path)
add_apt_repo() {
  local repo_line="$1"
  local repo_file="$2"
  info "Adding apt repo: $repo_file"
  echo "$repo_line" | tee "$repo_file" > /dev/null
  apt update
}

# Generic package installer via apt
apt_install_packages() {
  require_root
  apt update
  apt install -y "$@"
}

# Individual installers (thin wrappers, use helpers)
install_docker() {
  require_root
  info "Installing docker (engine + compose plugin)"
  apt-get update
  apt-get install -y ca-certificates curl gnupg
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
  echo "deb [arch="]$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo \"$VERSION_CODENAME\") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
  apt-get update
  apt_install_packages docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

install_citrix_client() {
  require_root
  info "Installing Citrix client from local .deb"
  if ! install_deb_from_assets 'icaclient_*.deb'; then
    warn "No local icaclient .deb found. Consider adding one to installation_files or implementing an auto-download step."
  fi
}

install_signal() {
  require_root
  info "Installing Signal Desktop (official repo)"
  wget -O- https://updates.signal.org/desktop/apt/keys.asc | gpg --dearmor > /usr/share/keyrings/signal-desktop-keyring.gpg
  echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/signal-desktop-keyring.gpg] https://updates.signal.org/desktop/apt xenial main' | tee /etc/apt/sources.list.d/signal-xenial.list
  apt_install_packages signal-desktop
}

install_tuxedo() {
  require_root
  info "Installing TUXEDO Control Center"
  local keyring="tuxedo-archive-keyring_2022.04.01~tux_all.deb"
  local keyurl="https://deb.tuxedocomputers.com/ubuntu/pool/main/t/tuxedo-archive-keyring/$keyring"
  wget -q "$keyurl" -O "/tmp/$keyring"
  dpkg -i "/tmp/$keyring"
  rm -f "/tmp/$keyring"
  local codename
  codename=$(lsb_release -cs)
  echo "deb [signed-by=/usr/share/keyrings/tuxedo-archive-keyring.gpg] https://deb.tuxedocomputers.com/ubuntu/ $codename main" | tee /etc/apt/sources.list.d/tuxedo.list > /dev/null
  apt_install_packages tuxedo-control-center tuxedo-drivers
}

install_zotero() {
  require_root
  info "Installing Zotero from tarball"
  install_tarball_to_opt 'Zotero-*_linux-x86_64.tar.bz2' zotero
  if [[ -x /opt/zotero/set_launcher_icon ]]; then
    /opt/zotero/set_launcher_icon
  fi
  ln -sf /opt/zotero/zotero.desktop /usr/share/applications/ || true
  chmod -R 707 /opt/zotero || true
  apt_install_packages default-jre libreoffice-java-common || true
}

# Install Insync via official APT repository when possible; fallback to local or env URL
install_insync() {
  require_root
  info "Installing Insync via APT repository (preferred)"

  # Detect distribution (ubuntu, debian, mint) and codename
  local os_id os_id_like distro codename
  if [[ -f /etc/os-release ]]; then
    os_id=$(awk -F= '/^ID=/ {print tolower($2)}' /etc/os-release | tr -d '"') || true
    os_id_like=$(awk -F= '/^ID_LIKE=/ {print tolower($2)}' /etc/os-release | tr -d '"') || true
    codename=$(awk -F= '/^VERSION_CODENAME=/ {print tolower($2)}' /etc/os-release | tr -d '"') || true
  fi
  if [[ -z "$codename" ]]; then
    codename=$(lsb_release -cs 2>/dev/null || true)
  fi
  # Normalize distro mapping
  if [[ "$os_id" == "ubuntu" || "$os_id_like" == *"ubuntu"* ]]; then
    distro=ubuntu
  elif [[ "$os_id" == "debian" || "$os_id_like" == *"debian"* ]]; then
    distro=debian
  elif [[ "$os_id" == "linuxmint" || "$os_id_like" == *"mint"* || "$os_id" == "mint" ]]; then
    distro=mint
  else
    # fallback to debian
    distro=debian
  fi

  info "Detected distro=$distro, codename=${codename:-unknown}"

  # Try to add the official apt repository
  local key_url="https://apt.insync.io/insynchq.gpg"
  if curl -fsSL "$key_url" | gpg --dearmor > /usr/share/keyrings/insynchq.gpg 2>/dev/null; then
    info "Imported Insync GPG key to /usr/share/keyrings/insynchq.gpg"
  else
    warn "Failed to import Insync GPG key from $key_url"
  fi

  if [[ -n "$codename" ]]; then
    local repo_file="/etc/apt/sources.list.d/insync.list"
    echo "deb http://apt.insync.io/$distro $codename non-free contrib" | tee "$repo_file" > /dev/null
    info "Wrote $repo_file"

    # Update and try installing insync via apt
    if apt-get update && apt-get install -y insync; then
      info "Installed insync from official APT repository"
      return 0
    else
      warn "Failed to install insync from APT repository; will fallback to local or direct download methods"
    fi
  else
    warn "Could not detect codename; skipping apt repository install for Insync"
  fi

  # Fallbacks: try local .deb first
  if install_deb_from_assets 'insync_*.deb'; then
    info "Installed Insync from local .deb"
    return 0
  fi

  # Try to discover a direct .deb link on vendor page (light scraping)
  info "Attempting to discover direct .deb link from vendor page..."
  local tmp url
  tmp="$(mktemp)"
  url="$(curl -fsSL 'https://www.insynchq.com/downloads/linux' 2>/dev/null | grep -oE 'https?://[^"'"'']*insync_[^"'"'']*\.deb' | head -n1 || true)"
  if [[ -n "$url" ]]; then
    info "Found Insync .deb URL: $url"
    wget -q -O "$tmp" "$url"
    apt -y install "$tmp" && rm -f "$tmp" && return 0 || true
  fi

  # ENV fallback
  if [[ -n "${INSYNC_DEB_URL:-}" ]]; then
    info "Using INSYNC_DEB_URL environment variable."
    wget -q -O "$tmp" "$INSYNC_DEB_URL"
    apt -y install "$tmp" && rm -f "$tmp" && return 0 || true
  fi

  warn "Could not auto-install Insync. Either place an insync_*.deb into installation_files/ or set INSYNC_DEB_URL to a direct .deb link."
  return 1
}

# List available installers
list_installers() {
  cat <<EOF
Available installers:
  docker
  citrix
  signal
  tuxedo
  zotero
  insync
Use: $0 --all  OR  $0 <name> [name...]
EOF
}

# Invoke requested installers
run_selected() {
  local -a to_run=("$@")
  for t in "${to_run[@]}"; do
    case "$t" in
      docker) install_docker ;;
      citrix) install_citrix_client ;;
      signal) install_signal ;;
      tuxedo) install_tuxedo ;;
      zotero) install_zotero ;;
      insync) install_insync ;;
      *)
        warn "Unknown installer: $t"
        ;;
    esac
  done
}

# CLI
if [[ ${#@} -eq 0 ]]; then
  list_installers
  exit 0
fi

if [[ "$1" == "--list" ]]; then
  list_installers
  exit 0
fi

if [[ "$1" == "--all" ]]; then
  run_selected docker citrix signal tuxedo zotero insync
  exit 0
fi

run_selected "$@"