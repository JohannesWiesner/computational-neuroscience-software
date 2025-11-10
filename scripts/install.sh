#!/usr/bin/env bash
# Unified installer for computational-neuroscience-software
# Place vendor .deb or tarball installers into ./installation_files and run:
#   ./scripts/install.sh --list
#   sudo ./scripts/install.sh --all
#   sudo ./scripts/install.sh zotero
set -euo pipefail

REPO_ROOT="$(cd ""$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
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
  else
    warn "No .deb matching '$pattern' in $INSTALL_DIR"
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
  echo "deb [arch=\