# computational-neuroscience-software

Consolidated installer helpers for commonly used software.

## Usage
- Place any vendor-provided .deb or tarball installers into the `installation_files/` directory.
- Use the unified installer script:
  - List installers: ./scripts/install.sh --list
  - Install a single package: sudo ./scripts/install.sh zotero
  - Install everything: sudo ./scripts/install.sh --all

### Notes
- The script needs root rights for system-level install steps.
- This repo contains the shellcheck github action to verify that the written code is valid

## Where to download .deb files

| Software | Download | Notes |
|----------|----------|-------|
| Insync | https://www.insynchq.com/downloads/linux | |
| Citrix Workspace Client | Newest version: https://www.citrix.com/downloads/workspace-app/linux/workspace-app-for-linux-latest.html<br>Legacy versions: https://www.citrix.com/downloads/workspace-app/legacy-workspace-app-for-linux/ | Currently only `icaclient_23.11.0.82_amd64.deb` is confirmed to work |
| Zotero | https://www.zotero.org/download/ | |
| Thunderbird | https://www.thunderbird.net/de/download/ | |
| DSI-Studio | https://dsi-studio.labsolver.org/download.html | |

