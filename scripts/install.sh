#!/usr/bin/env bash
# Unified installer for computational-neuroscience-software
# Place vendor .deb or tarball installers into ./installation_files and run:
#   ./scripts/install.sh --list
#   sudo ./scripts/install.sh --all
#   sudo ./scripts/install.sh insync
set -euo pipefail

REPO_ROOT="$(cd ""+"(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_DIR="${REPO_ROOT}/installation_files"

# Logging helpers
info()  { printf "\033[1;34m[INFO]\033[0m %s\n" "$*"; }
warn()  { printf "\033[1;33m[WARN]\033[0m %s\n" "$*"; }
error() { printf "\033[1;31m[ERROR]\033[0m %s\n" "$*" >&2; }

require_root() {
  if [[ $EUID -ne 0 ]]; then
    error "This script requires root privileges. Re-run with sudo."
    exit 1
  fi
}

find_asset() {
  local pattern="$1"
  find "$INSTALL_DIR" -maxdepth 1 -type f -name "$pattern" | head -n1 || true
}

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

apt_install_packages() {
  require_root
  apt update
  apt install -y "$@"
}

install_docker() {
  require_root
  info "Installing docker (engine + compose plugin)"
  apt-get update
  apt-get install -y ca-certificates curl gnupg
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
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

install_insync() {
  require_root
  info "Installing Insync via official APT repository (strict mode)"

  if [[ "$(dpkg --print-architecture)" != "amd64" ]]; then
    error "Insync only supports 64-bit (amd64). Aborting."
    return 1
  fi

  local os_id os_id_like distro codename
  if [[ -f /etc/os-release ]]; then
    os_id=$(awk -F= '/^ID=/ {print tolower($2)}' /etc/os-release | tr -d '"') || true
    os_id_like=$(awk -F= '/^ID_LIKE=/ {print tolower($2)}' /etc/os-release | tr -d '"') || true
    codename=$(awk -F= '/^VERSION_CODENAME=/ {print tolower($2)}' /etc/os-release | tr -d '"') || true
  fi
  if [[ -z "$codename" ]]; then
    codename=$(lsb_release -cs 2>/dev/null || true)
  fi

  if [[ "$os_id" == "ubuntu" || "$os_id_like" == *"ubuntu" ]]; then
    distro=ubuntu
  elif [[ "$os_id" == "debian" || "$os_id_like" == *"debian" ]]; then
    distro=debian
  elif [[ "$os_id" == "linuxmint" || "$os_id_like" == *"mint" || "$os_id" == "mint" ]]; then
    distro=mint
  else
    distro=debian
  fi

  info "Detected distro=$distro, codename=${codename:-unknown}"

  if [[ -z "$codename" ]]; then
    error "Could not detect distribution codename; cannot follow official Insync APT instructions. Aborting."
    return 1
  fi

  local key_url="https://apt.insync.io/insynchq.gpg"
  info "Importing Insync GPG key from $key_url to /etc/apt/trusted.gpg.d/insynchq.gpg"
  curl -L "$key_url" 2>/dev/null | gpg --dearmor | tee /etc/apt/trusted.gpg.d/insynchq.gpg >/dev/null

  local repo_file="/etc/apt/sources.list.d/insync.list"
  echo "deb http://apt.insync.io/$distro $codename non-free contrib" | tee "$repo_file" > /dev/null
  info "Wrote $repo_file"

  apt-get update

  apt-get install -y insync
  info "Insync installation attempted via official APT repository"
}

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