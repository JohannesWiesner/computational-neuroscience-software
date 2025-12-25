#!/usr/bin/env bash

set -Eeuo pipefail # fail directly
IFS=$'\n\t' # split strings only on new lines and tabs (not on whitespaces)

# get absolute path to where this script is located and the corresponding installation director
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_DIR="${REPO_ROOT}/installation_files"

# Logging helpers
info()  { printf "\033[1;34m[INFO]\033[0m %s\n" "$*"; }
warn()  { printf "\033[1;33m[WARN]\033[0m %s\n" "$*"; }
die()   { printf "\033[1;31m[ERROR]\033[0m %s\n" "$*" >&2; exit 1; }
require_root() { [[ ${EUID:-$(id -u)} -eq 0 ]] || die "Root required. Re-run with sudo." }

# ----------------------------------------------------------------------------------------------------------------
# Shared helpers across installation functions
# ----------------------------------------------------------------------------------------------------------------

APT_UPDATED=0
apt_update_once() {
  require_root
  if [[ "$APT_UPDATED" -eq 0 ]]; then
    apt-get update -y
    APT_UPDATED=1
  fi
}

apt_install_packages() {
  require_root
  apt_update_once
  apt-get install -y "$@"
}

find_asset() {
  local pattern="$1"
  find "$INSTALL_DIR" -maxdepth 1 -type f -name "$pattern" | head -n1 || true
}

install_deb_from_assets() {
  require_root
  local pattern="$1"
  local deb
  deb="$(find_asset "$pattern")"
  [[ -n "$deb" ]] || return 1
  apt_update_once
  info "Installing deb: $deb"
  apt-get install -y "$deb"
}

download_if_missing() {
  local url="$1" path="$2"
  mkdir -p "$INSTALL_DIR"
  if [[ -f "$path" ]]; then
    info "Using existing: $path"
  else
    info "Downloading: $url"
    wget -q -O "$path" "$url"
  fi
}

install_deb_url() {
  # Usage: install_deb_url <url> <filename>
  require_root
  local url="$1" name="$2"
  local path="${INSTALL_DIR}/${name}"
  download_if_missing "$url" "$path"
  apt_update_once
  info "Installing deb: $path"
  apt-get install -y "$path"
}

install_github_latest_deb() {
  # Usage: install_github_latest_deb <owner/repo> <grep-regex-for-deb-url>
  require_root
  local repo="$1" regex="$2"
  local api="https://api.github.com/repos/${repo}/releases/latest"
  local url tmp

  url="$(curl -fsSL "$api" | grep -oE "$regex" | head -n1 || true)"
  [[ -n "$url" ]] || return 1

  tmp="$(mktemp)"
  wget -q -O "$tmp" "$url"
  apt_update_once
  info "Installing deb from: $repo (latest)"
  apt-get install -y "$tmp"
  rm -f "$tmp"
}

install_archive_to_opt() {
  # Usage: install_archive_to_opt <pattern-in-assets> <opt-subdir>
  require_root
  local pattern="$1" dest="$2" asset
  asset="$(find_asset "$pattern")"
  [[ -n "$asset" ]] || return 1

  info "Extracting $(basename "$asset") to /opt/$dest"
  mkdir -p "/opt/$dest"

  case "$asset" in
    *.tar.bz2) tar -xjf "$asset" --strip-components=1 -C "/opt/$dest" ;;
    *.tar.xz)  tar -xJf "$asset" --strip-components=1 -C "/opt/$dest" ;;
    *.tar.gz|*.tgz) tar -xzf "$asset" --strip-components=1 -C "/opt/$dest" ;;
    *.zip)     unzip -o "$asset" -d "/opt/$dest" >/dev/null ;;
    *) die "Unknown archive type: $asset" ;;
  esac
}

# -----------------------------------------------------------------------------------------------------------------------------------------------
# Installer functions
# ------------------------------------------------------------------------------------------------------------------------------------------------

install_citrix_client() {
  require_root
  info "Installing Citrix client (expecting local .deb)"
  install_deb_from_assets 'icaclient_*.deb' \
    || warn "No local icaclient .deb found; add icaclient_*.deb to installation_files/"
}

install_docker() {
  require_root
  info "Installing Docker (engine + compose plugin)"
  apt_install_packages ca-certificates curl gnupg
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    > /etc/apt/sources.list.d/docker.list
  APT_UPDATED=0
  apt_install_packages docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

install_drawio() {
  require_root
  info "Installing draw.io desktop"
  apt_install_packages openjdk-11-jre-headless xvfb xauth
  install_github_latest_deb "jgraph/drawio-desktop" 'https://[^"]+drawio-amd64-[0-9.]+\.deb' \
    || warn "Could not find latest drawio automatically; add drawio-amd64-*.deb to installation_files/."
}

install_dsistudio() {
  require_root
  info "Installing DSI-Studio (local zip expected)"
  install_archive_to_opt 'dsi_studio*.zip' 'dsi-studio' \
    && chmod -R 755 /opt/dsi-studio || warn "No DSI-Studio zip in installation_files/ (dsi_studio*.zip)"
}

install_ferdium() {
  require_root
  info "Installing Ferdium"
  install_deb_from_assets 'Ferdium*.deb' \
    || install_deb_from_assets 'ferdium_*.deb' \
    || warn "No Ferdium .deb found in installation_files/"
}

install_googlechrome() {
  require_root
  info "Installing Google Chrome"
  install_deb_url "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb" \
                  "google-chrome-stable_current_amd64.deb"
}

install_zoomclient() {
  require_root
  info "Installing Zoom"
  install_deb_url "https://zoom.us/client/latest/zoom_amd64.deb" "zoom_amd64.deb"
}

install_onlyoffice() {
  require_root
  info "Installing OnlyOffice"
  install_deb_url "https://github.com/ONLYOFFICE/DesktopEditors/releases/latest/download/onlyoffice-desktopeditors_amd64.deb" \
                  "onlyoffice-desktopeditors_amd64.deb"
}

install_guvcview() { require_root; info "Installing guvcview"; apt_install_packages guvcview || warn "Not available"; }
install_steam()    { require_root; info "Installing steam";    apt_install_packages steam || warn "Not available"; }
install_octave()   { require_root; info "Installing Octave";   apt_install_packages octave; }

install_micromamba() {
  info "Installing micromamba (user-local install)"
  "${SHELL}" <(curl -fsSL micro.mamba.pm/install.sh)
}

install_mricrogl() {
  require_root
  info "Installing MRIcroGL (latest)"
  local tmp; tmp="$(mktemp -d)"
  if curl -fsSL -o "$tmp/MRIcroGL_linux.zip" https://github.com/rordenlab/MRIcroGL/releases/latest/download/MRIcroGL_linux.zip; then
    mkdir -p /opt/MRIcroGL
    unzip -o "$tmp/MRIcroGL_linux.zip" -d /opt/MRIcroGL >/dev/null
    chmod -R 755 /opt/MRIcroGL || true
  else
    warn "Failed to download MRIcroGL automatically; add MRIcroGL_linux.zip to installation_files/"
  fi
  rm -rf "$tmp"
}

install_obsidian() {
  require_root
  info "Installing Obsidian (latest)"
  install_github_latest_deb "obsidianmd/obsidian-releases" 'https://[^"]+linux.*\.deb' \
    || warn "Could not auto-download Obsidian; add obsidian_*.deb to installation_files/"
}

install_nextcloud() {
  require_root
  info "Installing Nextcloud client"
  apt_install_packages nextcloud-desktop 2>/dev/null \
    || apt_install_packages nextcloud-client 2>/dev/null \
    || warn "Nextcloud client not available via apt package names on this system."
}

install_signal() {
  require_root
  info "Installing Signal Desktop (official repo)"
  curl -fsSL https://updates.signal.org/desktop/apt/keys.asc | gpg --dearmor > /usr/share/keyrings/signal-desktop-keyring.gpg
  echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/signal-desktop-keyring.gpg] https://updates.signal.org/desktop/apt xenial main' \
    > /etc/apt/sources.list.d/signal-xenial.list
  APT_UPDATED=0
  apt_install_packages signal-desktop
}

install_spotify() {
  require_root
  info "Installing Spotify (official repo)"
  curl -fsSL https://download.spotify.com/debian/pubkey_5E3C45D7B312C643.gpg | gpg --dearmor > /usr/share/keyrings/spotify-archive-keyring.gpg || true
  echo "deb [signed-by=/usr/share/keyrings/spotify-archive-keyring.gpg] http://repository.spotify.com stable non-free" \
    > /etc/apt/sources.list.d/spotify.list
  APT_UPDATED=0
  apt_install_packages spotify-client || apt_install_packages spotify-client-gtk || warn "Could not install spotify-client; check repository"
}

install_tuxedo() {
  require_root
  info "Installing TUXEDO Control Center"
  local keyring="tuxedo-archive-keyring_2022.04.01~tux_all.deb"
  install_deb_url "https://deb.tuxedocomputers.com/ubuntu/pool/main/t/tuxedo-archive-keyring/${keyring}" "$keyring"
  echo "deb [signed-by=/usr/share/keyrings/tuxedo-archive-keyring.gpg] https://deb.tuxedocomputers.com/ubuntu/ $(lsb_release -cs) main" \
    > /etc/apt/sources.list.d/tuxedo.list
  APT_UPDATED=0
  apt_install_packages tuxedo-control-center tuxedo-drivers
}

install_zotero() {
  require_root
  info "Installing Zotero from tarball (local expected)"
  if install_archive_to_opt 'Zotero-*_linux-x86_64.tar.bz2' zotero; then
    [[ -x /opt/zotero/set_launcher_icon ]] && /opt/zotero/set_launcher_icon || true
    ln -sf /opt/zotero/zotero.desktop /usr/share/applications/ || true
    chmod -R 707 /opt/zotero || true
    apt_install_packages default-jre libreoffice-java-common || true
  else
    warn "No Zotero tarball found in installation_files/"
  fi
}

install_thunderbird() {
  require_root
  info "Installing Thunderbird (local tarball expected)"
  install_archive_to_opt 'thunderbird*.tar.xz' thunderbird \
    && chmod -R 755 /opt/thunderbird || warn "No thunderbird tarball found in installation_files/"
}

install_calibre() {
  require_root
  info "Installing Calibre"
  wget -nv -O- https://download.calibre-ebook.com/linux-installer.sh | sh /dev/stdin
}

# ------------------------------------------------------------------------------------------------------------
# Client (run selected or all installers)
# ------------------------------------------------------------------------------------------------------------

declare -A INSTALLERS=(
  [citrix]=install_citrix_client
  [docker]=install_docker
  [drawio]=install_drawio
  [dsi-studio]=install_dsistudio
  [ferdium]=install_ferdium
  [googlechrome]=install_googlechrome
  [guvcview]=install_guvcview
  [insync]=install_insync
  [micromamba]=install_micromamba
  [mricrogl]=install_mricrogl
  [nextcloud]=install_nextcloud
  [obsidian]=install_obsidian
  [octave]=install_octave
  [signal]=install_signal
  [spotify]=install_spotify
  [tuxedo]=install_tuxedo
  [zoom]=install_zoomclient
  [zotero]=install_zotero
  [steam]=install_steam
  [onlyoffice]=install_onlyoffice
  [thunderbird]=install_thunderbird
  [calibre]=install_calibre
)

list_installers() {
  echo "Available installers:"
  for k in "${!INSTALLERS[@]}"; do echo "  $k"; done | sort
  echo
  echo "Use: $0 --all  OR  $0 <name> [name...]"
}

run_selected() {
  local name fn
  for name in "$@"; do
    fn="${INSTALLERS[$name]:-}"
    if [[ -z "$fn" ]]; then
      warn "Unknown installer: $name"
      continue
    fi
    info "=== $name ==="
    "$fn"
  done
}

run_all() {
  run_selected "${!INSTALLERS[@]}"
}

# ------------------------------------------------------------------------------------------------------------------------
# CLI
# ------------------------------------------------------------------------------------------------------------------------

if [[ $# -eq 0 ]]; then
  list_installers
  exit 0
fi

case "${1:-}" in
  --list) list_installers; exit 0 ;;
  --all)  run_all; exit 0 ;;
esac

run_selected "$@"
