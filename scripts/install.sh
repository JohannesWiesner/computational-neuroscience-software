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
require_root() { [[ ${EUID:-$(id -u)} -eq 0 ]] || die "Root required. Re-run with sudo."; }

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
  # Usage: install_github_latest_deb <owner/repo> <name>
  require_root
  local repo="$1"
  local name="$2"
  local api="https://api.github.com/repos/${repo}/releases/latest"
  local url

  # gets the exact url to the .deb file
  url=$(curl -fsSL "$api" | jq -r '.assets[] | select(.name | test("(x86_64|amd64).*\\.deb$")) | .browser_download_url' | head -n1)
  [[ -n "$url" ]] || die "Could not find URL to .deb file from from the .json file provided by the Github API"

  # downloads the .deb file and installs application
  install_deb_url $url $name
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
    *.zip)     unzip -o -j "$asset" -d "/opt/$dest" >/dev/null ;;
    *) die "Unknown archive type: $asset" ;;
  esac
}

ensure_flatpak() {
  # Ensure that flatpak is installed. If not, install it and add the flathub repository.
  if ! command -v flatpak >/dev/null 2>&1; then
    require_root
    info "Installing flatpak"
    apt_install_packages flatpak
  fi

  # Ensure Flathub exists (idempotent)
  if ! flatpak remotes | awk '{print $1}' | grep -qx flathub; then
    info "Adding Flathub remote"
    flatpak remote-add --if-not-exists flathub \
      https://dl.flathub.org/repo/flathub.flatpakrepo
  fi
}

# -----------------------------------------------------------------------------------------------------------------------------------------------
# Installer functions
# ------------------------------------------------------------------------------------------------------------------------------------------------

install_pdf_sam() {
  require_root
  info "Installing PDFsam"
  install_deb_from_assets 'pdfsam*.deb' || warn "No local PDFsam .deb found; add pdfsam*.deb to installation_files/"
}

install_remmina()  {
  ensure_flatpak
  info "Installing flatpak app: Remmina"
  flatpak install -y flathub org.remmina.Remmina
}

install_disk_usage_analyzer() {
  ensure_flatpak
  info "Installing flatpak app: Disk Usage Analyzer"
  flatpak install -y flathub org.gnome.baobab
}

install_citrix_client() {
  require_root
  info "Installing Citrix client (expecting local .deb)"
  install_deb_from_assets 'icaclient_*.deb' || warn "No local icaclient .deb found; add icaclient_*.deb to installation_files/"

  # Ubuntu 24.04: SelfService needs WebKitGTK 4.0 from Jammy (Citrix backport note)
  # See: https://docs.citrix.com/de-de/citrix-workspace-app-for-linux/system-requirements.html
  info "Installing necessary dependencies for Citrix Workspace Client"

  apt-add-repository -y "deb http://us.archive.ubuntu.com/ubuntu jammy main"
  apt-add-repository -y "deb http://us.archive.ubuntu.com/ubuntu jammy-updates main"
  apt-add-repository -y "deb http://us.archive.ubuntu.com/ubuntu jammy-security main"

  apt update
  apt install -y libwebkit2gtk-4.0-dev

  apt-add-repository -y -r "deb http://us.archive.ubuntu.com/ubuntu jammy main"
  apt-add-repository -y -r "deb http://us.archive.ubuntu.com/ubuntu jammy-updates main"
  apt-add-repository -y -r "deb http://us.archive.ubuntu.com/ubuntu jammy-security main"

  apt update

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
  install_github_latest_deb "jgraph/drawio-desktop" "drawio.deb" || warn "Could not install drawio"
}

install_dsistudio() {
  require_root
  info "Installing DSI-Studio (local zip expected)"
  apt_install_packages libqt6charts6-dev # See: https://dsi-studio.labsolver.org/download.html
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
  install_github_latest_deb "ONLYOFFICE/DesktopEditors" "onlyoffice-desktopeditors.deb" || warn "Could not install OnlyOffice Desktop Editors"
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
  curl -sS https://download.spotify.com/debian/pubkey_5384CE82BA52C83A.asc | gpg --dearmor --yes -o /etc/apt/trusted.gpg.d/spotify.gpg
  echo "deb https://repository.spotify.com stable non-free" | tee /etc/apt/sources.list.d/spotify.list
  APT_UPDATED=0
  apt_install_packages spotify-client || warn "Could not install spotify-client; check repository"
}

install_tuxedocontrolcenter() {
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

install_insync() {
  require_root
  info "Installing Insync"
  install_deb_from_assets 'insync_*.deb' \
    || warn "No local insync .deb found; add insync_*.deb to installation_files/"
}

# ------------------------------------------------------------------------------------------------------------
# Client (run selected or all installers)
# ------------------------------------------------------------------------------------------------------------

declare -A INSTALLERS=(
  [pdfsam]=install_pdf_sam
  [remmina]=install_remmina
  [disk_usage_analyzer]=install_disk_usage_analyzer
  [citrix]=install_citrix_client
  [docker]=install_docker
  [drawio]=install_drawio
  [dsistudio]=install_dsistudio
  [ferdium]=install_ferdium
  [googlechrome]=install_googlechrome
  [guvcview]=install_guvcview
  [micromamba]=install_micromamba
  [mricrogl]=install_mricrogl
  [nextcloud]=install_nextcloud
  [obsidian]=install_obsidian
  [octave]=install_octave
  [signal]=install_signal
  [spotify]=install_spotify
  [tuxedocontrolcenter]=install_tuxedocontrolcenter
  [zoom]=install_zoomclient
  [zotero]=install_zotero
  [steam]=install_steam
  [onlyoffice]=install_onlyoffice
  [thunderbird]=install_thunderbird
  [calibre]=install_calibre
  [insync]=install_insync

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
