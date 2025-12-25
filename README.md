# computational-neuroscience-software

Consolidated installer helpers for commonly used software.

Usage
- Place any vendor-provided .deb or tarball installers into the `installation_files/` directory.
- Use the unified installer script:
  - List installers: ./scripts/install.sh --list
  - Install a single package: sudo ./scripts/install.sh zotero
  - Install everything: sudo ./scripts/install.sh --all

Notes
- The script needs root rights for system-level install steps.
- Consider running static checks (shellcheck) in CI:
  - Install ShellCheck and run: shellcheck scripts/install.sh
- Keep large vendor artifacts in `installation_files/` to avoid committing binaries directly to git history.


## Download pages

Insync : https://www.insynchq.com/downloads/linux
Citrix Client : https://www.citrix.com/downloads/workspace-app/linux/workspace-app-for-linux-latest.html

or this page for older releases if the newest one does not work: https://www.citrix.com/downloads/workspace-app/legacy-workspace-app-for-linux/?srsltid=AfmBOoq-Vih24iosurRPrw5o0zC6pHFnphOWgVfTY6qhFjBKOf_nA4Kj

Working version: icaclient_23.11.0.82_amd64.deb

Zotero: https://www.zotero.org/download/

Thunderbird: https://www.thunderbird.net/de/download/

DSI-Studio: https://dsi-studio.labsolver.org/download.html
