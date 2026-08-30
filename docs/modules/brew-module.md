# Homebrew / Linuxbrew Module Documentation

Technical specification of the cross-platform package management subsystem (`brew/`).

---

## 1. Module Overview

The `brew` module provides automated installation, batch package provisioning, routine upgrades, and health validation for Homebrew (macOS) and Linuxbrew (Linux).

---

## 2. File Manifest

| File | Type | Description |
|---|---|---|
| [`brew/install-homebrew.sh`](file:///rocky/home/gmb/repos/env-setup/brew/install-homebrew.sh) | Executable Script | Headless installer provisioning Homebrew on macOS or Linuxbrew on Linux. |
| [`brew/setup.sh`](file:///rocky/home/gmb/repos/env-setup/brew/setup.sh) | Executable Script | Installs configured formulae (`BREW_FORMULAE`) and macOS casks (`BREW_CASKS`). |
| [`brew/update-brew.sh`](file:///rocky/home/gmb/repos/env-setup/brew/update-brew.sh) | Executable Script | Executes `brew update` and upgrades outdated configured packages. |
| [`brew/verify.sh`](file:///rocky/home/gmb/repos/env-setup/brew/verify.sh) | Executable Script | Validates Homebrew binary presence, installed formulae, and macOS casks. |
| [`brew/config.defaults`](file:///rocky/home/gmb/repos/env-setup/brew/config.defaults) | Configuration | Declares default formulae and cask package lists. |
| [`brew/lib/common.sh`](file:///rocky/home/gmb/repos/env-setup/brew/lib/common.sh) | Library | Cross-platform path resolution, formula/cask lifecycle management, and preflight checks. |

---

## 3. Cross-Platform Path Resolution

[`brew/lib/common.sh`](file:///rocky/home/gmb/repos/env-setup/brew/lib/common.sh) dynamically discovers and exports the Homebrew environment across all installation targets:

```bash
ensure_brew_in_path() {
  if command -v brew >/dev/null 2>&1; then
    return 0
  fi
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
    return 0
  fi
  if [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
    return 0
  fi
  if [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    return 0
  fi
  return 1
}
```

---

## 4. Formula vs Cask Isolation

Homebrew distinguishes between command-line utilities (formulae) and macOS GUI applications (casks). The module enforces platform isolation:

- **Formulae** (`BREW_FORMULAE`): Installed and verified on both macOS and Linux.
  `tree`, `gh`, `awscli@2`, `kubectl`, `helm`, `python3`, `argocd`, `sshpass`, `node`, `nano`.
- **Casks** (`BREW_CASKS`): Installed and verified exclusively on macOS (`detect_os == darwin`).
  `nimble-commander`, `wezterm`, `lens`, `freelens`.
  On Linux, cask installation and verification routines gracefully bypass with an informational log.

---

## 5. Verification Subsystem (`verify.sh`)

`verify.sh` performs the following checks:
1. Validates that `brew` is executable in PATH.
2. Checks each formula in `BREW_FORMULAE` using `brew list --formula <pkg>`.
3. If running on macOS, checks each cask in `BREW_CASKS` using `brew list --cask <cask>`.
4. Checks for outdated packages among configured items.
5. Returns exit code `0` on 100% pass, or `1` if any configured package is missing.