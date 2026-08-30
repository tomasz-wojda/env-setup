# Shell Module Documentation

Technical specification of the shell integration and CLI tool provisioning subsystem (`shell/` and `env-setup.env.zsh`).

---

## 1. Module Overview

The shell module manages the developer's interactive Zsh environment, provisions critical command-line tools (`zsh`, `nano`), installs unified environment sourcing hooks in `~/.zshrc`, and defines productivity functions.

---

## 2. File Manifest

| File | Type | Description |
|---|---|---|
| [`shell/setup.sh`](file:///rocky/home/gmb/repos/env-setup/shell/setup.sh) | Executable Script | Automated bootstrapper provisioning `zsh` and `nano`, and writing unified hook into `~/.zshrc`. |
| [`shell/verify.sh`](file:///rocky/home/gmb/repos/env-setup/shell/verify.sh) | Executable Script | Validates binary presence (`zsh`, `nano`), `~/.zshrc` hook configuration, and subshell function runtime availability. |
| [`shell/config.defaults`](file:///rocky/home/gmb/repos/env-setup/shell/config.defaults) | Configuration | Declares hook delimiters, monitored shell functions (`ls ssh gss glo gcam`), and package names. |
| [`shell/lib/common.sh`](file:///rocky/home/gmb/repos/env-setup/shell/lib/common.sh) | Library | Linux package manager detection (`dnf`, `apt-get`, `yum`, `pacman`, `zypper`, `brew`), package installation, and hook stripping. |
| [`shell/shell.env.zsh`](file:///rocky/home/gmb/repos/env-setup/shell/shell.env.zsh) | Shell Hook | Defines `ls`, `ssh`, `gss`, `glo`, `gcam` with safe unaliasing. |
| [`env-setup.env.zsh`](file:///rocky/home/gmb/repos/env-setup/env-setup.env.zsh) | Root Sourcing Hook | Single unified entrypoint for `~/.zshrc` sourcing `shell.env.zsh` and `groovy.env.zsh`. |

---

## 3. Automated Tool Provisioning Engine

[`shell/lib/common.sh`](file:///rocky/home/gmb/repos/env-setup/shell/lib/common.sh) contains distribution-agnostic package provisioning logic:

```bash
install_linux_package() {
  local pkg="$1"
  local pm sudo_cmd=""
  pm="$(detect_linux_package_manager)"

  if [[ "$(id -u)" -ne 0 ]]; then
    if command -v sudo >/dev/null 2>&1; then
      sudo_cmd="sudo"
    else
      die_preflight "Root privileges or sudo required to install $pkg via $pm"
    fi
  fi

  case "$pm" in
    dnf)     $sudo_cmd dnf install -y "$pkg" ;;
    apt-get) $sudo_cmd apt-get update && $sudo_cmd apt-get install -y "$pkg" ;;
    yum)     $sudo_cmd yum install -y "$pkg" ;;
    pacman)  $sudo_cmd pacman -S --noconfirm "$pkg" ;;
    zypper)  $sudo_cmd zypper install -y "$pkg" ;;
    brew)    brew install "$pkg" ;;
    *)       die_install "No supported package manager detected on Linux" ;;
  esac
}
```

---

## 4. Idempotent `~/.zshrc` Hook Lifecycle

`ensure_zshrc_hook` ensures that the user's `~/.zshrc` contains exactly one clean entrypoint block:

```bash
# >>> env-setup >>>
source "/home/gmb/repos/env-setup/env-setup.env.zsh"
# <<< env-setup <<<
```

### Hook Stripping Logic
Before appending a new hook block, `strip_zshrc_env_hooks` parses `~/.zshrc` with `awk` to remove existing or legacy blocks (`# >>> env-setup groovy >>>`), guaranteeing that multiple runs of `setup.sh` never create redundant or conflicting hooks.

---

## 5. Non-Zsh Sourcing Guard

To prevent shell initialization errors if `env-setup.env.zsh` is erroneously sourced in GNU Bash or sh, an early runtime guard aborts execution gracefully:

```zsh
if [[ -z "${ZSH_VERSION:-}" ]]; then
  echo "env-setup: env-setup.env.zsh requires Zsh. Current shell is not Zsh (skipping)." >&2
  return 1 2>/dev/null || exit 1
fi
```