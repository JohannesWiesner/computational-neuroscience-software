#!/usr/bin/env bash
# Unified installer for computational-neuroscience-software
# Supports: citrix, docker, drawio, dsi-studio, ferdium, googlechrome, guvcview,
#           insync, micromamba, mricrogl, nextcloud, obsidian, octave,
#           signal, spotify, tuxedo, zoom, zotero
#
# Usage:
#   ./scripts/install.sh --list
#   sudo ./scripts/install.sh --all
#   sudo ./scripts/install.sh insync docker zotero
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
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

# Helpers
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
    return 0
  else
    return 1
  fi
}

apt_install_packages() {
  require_root
  apt update
  apt install -y "$@"
}

# Individual installers

install_citrix_client() {
  require_root
  info "Installing Citrix client (expecting local .deb)"
  if ! install_deb_from_assets 'icaclient_*.deb'; then
    warn "No local icaclient .deb found; please add icaclient_*.deb to installation_files/"
  fi
}

install_docker() {
  require_root
  info "Installing Docker (engine + compose plugin)"
  apt-get update
  apt-get install -y ca-certificates curl gnupg
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo \"$VERSION_CODENAME\") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
  apt-get update
  apt_install_packages docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

install_drawio() {
  require_root
  info "Installing draw.io desktop"
  apt_install_packages openjdk-11-jre-headless xvfb xauth
  tmp="$(mktemp)"
  api_url="https://api.github.com/repos/jgraph/drawio-desktop/releases/latest"
  url="$(curl -fsSL "$api_url" 2>/dev/null | grep -oE 'https://[^"]+drawio-amd64-[0-9.]+\.deb' | head -n1 || true)"
  if [[ -n "$url" ]]; then
    wget -q -O "$tmp" "$url"
    apt -y install "$tmp"
    rm -f "$tmp"
  else
    warn "Could not find latest drawio release automatically. You may place drawio-amd64-*.deb into installation_files/ and run this again."
  fi
}

install_dsistudio() {
  require_root
  info "Installing DSI-Studio (local zip expected)"
  apt_install_packages libqt6charts6-dev unzip || true
  if install_tarball_to_opt 'dsi_studio*.zip' 'dsi-studio'; then
    chmod -R 755 /opt/dsi-studio || true
  else
    warn "No DSI-Studio zip in installation_files/ (look for dsi_studio*.zip)"
  fi
}

install_ferdium() {
  require_root
  info "Installing Ferdium"
  if ! install_deb_from_assets 'Ferdium*.deb' && ! install_deb_from_assets 'ferdium_*.deb'; then
    warn "No Ferdium .deb found in installation_files/"
  fi
}

install_googlechrome() {
  require_root
  info "Installing Google Chrome (stable)"
  tmp="$(mktemp)"
  wget -q -O "$tmp" https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
  apt -y install "$tmp" && rm -f "$tmp"
}

install_guvcview() {
  require_root
  info "Installing guvcview"
  apt_install_packages guvcview || warn "guvcview not available in apt for your distro"
}

install_insync() {
  require_root
  info "Installing Insync via official APT repository (strict mode)"
  # Insync supports amd64 only
  if [[ "$(dpkg --print-architecture)" != "amd64" ]]; then
    error "Insync only supports 64-bit (amd64). Aborting."
    return 1
  fi
  # detect distro and codename
  local os_id os_id_like distro codename
  if [[ -f /etc/os-release ]]; then
    os_id=$(awk -F= '/^ID=/ {print tolower($2)}' /etc/os-release | tr -d '\"') || true
    os_id_like=$(awk -F= '/^ID_LIKE=/ {print tolower($2)}' /etc/os-release | tr -d '\"') || true
    codename=$(awk -F= '/^VERSION_CODENAME=/ {print tolower($2)}' /etc/os-release | tr -d '\"') || true
  fi
  if [[ -z "$codename" ]]; then
    codename=$(lsb_release -cs 2>/dev/null || true)
  fi
  if [[ "$os_id" == "ubuntu" || "$os_id_like" == *"ubuntu"* ]]; then
    distro=ubuntu
  elif [[ "$os_id" == "debian" || "$os_id_like" == *"debian"* ]]; then
    distro=debian
  elif [[ "$os_id" == "linuxmint" || "$os_id_like" == *"mint"* || "$os_id" == "mint" ]]; then
    distro=mint
  else
    distro=debian
  fi
  if [[ -z "$codename" ]]; then
    error "Could not detect distribution codename; cannot follow official Insync APT instructions. Aborting."
    return 1
  fi
  info "Detected distro=$distro, codename=$codename"
  # STEP 1: Add public GPG key
  curl -L https://apt.insync.io/insynchq.gpg 2>/dev/null | gpg --dearmor | tee /etc/apt/trusted.gpg.d/insynchq.gpg >/dev/null
  # STEP 2: Write apt source list
  echo "deb http://apt.insync.io/$distro $codename non-free contrib" | tee /etc/apt/sources.list.d/insync.list > /dev/null
  # STEP 3: Update
  apt-get update
  # STEP 4: Install
  apt-get install -y insync
}

# https://mamba.readthedocs.io/en/latest/installation/micromamba-installation.html#automatic-install
install_micromamba() {
  info "Installing micromamba (user-local install)"
  "${SHELL}" <(curl -L micro.mamba.pm/install.sh)
}

install_mricrogl() {
  require_root
  info "Installing MRIcroGL (latest)"
  mkdir -p "$INSTALL_DIR"
  tmp="$(mktemp -d)"
  curl -fsSL -o "$tmp/MRIcroGL_linux.zip" https://github.com/rordenlab/MRIcroGL/releases/latest/download/MRIcroGL_linux.zip || true
  if [[ -f "$tmp/MRIcroGL_linux.zip" ]]; then
    unzip -o "$tmp/MRIcroGL_linux.zip" -d /opt/MRIcroGL
    chmod -R 755 /opt/MRIcroGL || true
    rm -rf "$tmp"
  else
    warn "Failed to download MRIcroGL automatically; you may add MRIcroGL_linux.zip to installation_files/"
  fi
}

install_nextcloud() {
  require_root
  info "Installing Nextcloud client"
  # try the common package names
  if apt_install_packages nextcloud-desktop 2>/dev/null; then
    return 0
  fi
  if apt_install_packages nextcloud-client 2>/dev/null; then
    return 0
  fi
  warn "Nextcloud client not available via apt package names on this system; consider adding distribution-specific repository or a local package to installation_files/"
}

install_obsidian() {
  require_root
  info "Installing Obsidian (GitHub latest release)"
  tmp="$(mktemp)"
  api="https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest"
  url="$(curl -fsSL "$api" 2>/dev/null | grep -oE 'https://[^"]+linux.*\.deb' | head -n1 || true)"
  if [[ -n "$url" ]]; then
    wget -q -O "$tmp" "$url"
    apt -y install "$tmp"
    rm -f "$tmp"
  else
    warn "Could not auto-download Obsidian; place obsidian_*.deb into installation_files/ and run this installer."
  fi
}

install_octave() {
  require_root
  info "Installing Octave"
  apt_install_packages octave
}

install_signal() {
  require_root
  info "Installing Signal Desktop (official repo)"
  wget -O- https://updates.signal.org/desktop/apt/keys.asc | gpg --dearmor > /usr/share/keyrings/signal-desktop-keyring.gpg
  echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/signal-desktop-keyring.gpg] https://updates.signal.org/desktop/apt xenial main' | tee /etc/apt/sources.list.d/signal-xenial.list
  apt_install_packages signal-desktop
}

install_spotify() {
  require_root
  info "Installing Spotify (official repo)"
  curl -sS https://download.spotify.com/debian/pubkey_5E3C45D7B312C643.gpg | gpg --dearmor > /usr/share/keyrings/spotify-archive-keyring.gpg || true
  echo "deb [signed-by=/usr/share/keyrings/spotify-archive-keyring.gpg] http://repository.spotify.com stable non-free" | tee /etc/apt/sources.list.d/spotify.list > /dev/null
  apt-get update
  apt_install_packages spotify-client || apt_install_packages spotify-client-gtk || warn "Could not install spotify-client; check repository"
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

install_zoomclient() {
  require_root
  info "Installing Zoom client (deb)"
  tmp="$(mktemp)"
  wget -q -O "$tmp" https://zoom.us/client/latest/zoom_amd64.deb
  apt -y install "$tmp" && rm -f "$tmp"
}

install_zotero() {
  require_root
  info "Installing Zotero from tarball (local tarball expected)"
  if install_tarball_to_opt 'Zotero-*_linux-x86_64.tar.bz2' zotero; then
    if [[ -x /opt/zotero/set_launcher_icon ]]; then
      /opt/zotero/set_launcher_icon
    fi
    ln -sf /opt/zotero/zotero.desktop /usr/share/applications/ || true
    chmod -R 707 /opt/zotero || true
    apt_install_packages default-jre libreoffice-java-common || true
  else
    warn "No Zotero tarball found in installation_files/ (Zotero-*_linux-x86_64.tar.bz2)"
  fi
}

# List available installers
list_installers() {
  cat <<EOF
Available installers:
  citrix
  docker
  drawio
  dsi-studio
  ferdium
  googlechrome
  guvcview
  insync
  micromamba
  mricrogl
  nextcloud
  obsidian
  octave
  signal
  spotify
  tuxedo
  zoom
  zotero
Use: $0 --all  OR  $0 <name> [name...]
EOF
}

# Dispatcher
run_selected() {
  local -a to_run=("$@")
  for t in "${to_run[@]}"; do
    case "$t" in
      citrix) install_citrix_client ;;
      docker) install_docker ;;
      drawio) install_drawio ;;
      dsi-studio|dsistudio|dsistudio) install_dsistudio ;;
      ferdium) install_ferdium ;;
      googlechrome|chrome) install_googlechrome ;;
      guvcview) install_guvcview ;;
      insync) install_insync ;;
      micromamba) install_micromamba ;;
      mricrogl|mricrogl) install_mricrogl ;;
      nextcloud) install_nextcloud ;;
      obsidian) install_obsidian ;;
      octave) install_octave ;;
      signal) install_signal ;;
      spotify) install_spotify ;;
      tuxedo|tuxedo-control-center) install_tuxedo ;;
      zoom|zoomclient) install_zoomclient ;;
      zotero) install_zotero ;;
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
  run_selected citrix docker drawio dsi-studio ferdium googlechrome guvcview insync micromamba mricrogl nextcloud obsidian octave signal spotify tuxedo zoom zotero
  exit 0
fi

run_selected "$@"
