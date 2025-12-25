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
