#!/usr/bin/env bash
# Shell environment configuration, CLI tool provisioning, and hook lifecycle management functions.

# Resolves the absolute root directory of the env-setup repository.
# Inputs: None
# Outputs: Echoes canonical directory path
resolve_env_setup_root() {
  local src="${BASH_SOURCE[1]:-${BASH_SOURCE[0]}}"
  while [[ -L "$src" ]]; do
    local dir
    dir="$(cd -P "$(dirname "$src")" && pwd)"
    src="$(readlink "$src")"
    [[ "$src" != /* ]] && src="$dir/$src"
  done
  cd -P "$(dirname "$src")/../.." && pwd
}

# Initializes shell common subsystem, resolves paths, sources logging and config.
# Inputs: None
# Outputs: None
init_shell_common() {
  if [[ -z "${SHELL_SCRIPT_DIR:-}" ]]; then
    SHELL_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  fi
  if [[ -z "${ENV_SETUP_ROOT:-}" ]]; then
    ENV_SETUP_ROOT="$(resolve_env_setup_root)"
  fi
  # shellcheck source=../../groovy/lib/logging.sh
  source "$ENV_SETUP_ROOT/groovy/lib/logging.sh"
  load_shell_config
}

# Loads default and local shell configuration values.
# Inputs: None
# Outputs: None
load_shell_config() {
  # shellcheck source=../config.defaults
  source "$SHELL_SCRIPT_DIR/config.defaults"
  if [[ -f "$SHELL_SCRIPT_DIR/config.local.sh" ]]; then
    # shellcheck source=/dev/null
    source "$SHELL_SCRIPT_DIR/config.local.sh"
  fi
}

# Detects host operating system kernel and normalizes the OS name.
# Inputs: None (reads uname -s)
# Outputs: Echoes normalized OS identifier ('darwin', 'linux', 'windows', 'unknown')
detect_os() {
  local u
  u="$(uname -s)"
  case "$u" in
    Darwin) echo "darwin" ;;
    Linux) echo "linux" ;;
    MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
    *) echo "unknown" ;;
  esac
}

# Detects the active package manager available on a Linux distribution.
# Inputs: None
# Outputs: Echoes package manager identifier ('dnf', 'apt-get', 'yum', 'pacman', 'zypper', 'brew', or 'unknown')
detect_linux_package_manager() {
  if command -v dnf >/dev/null 2>&1; then
    echo "dnf"
  elif command -v apt-get >/dev/null 2>&1; then
    echo "apt-get"
  elif command -v yum >/dev/null 2>&1; then
    echo "yum"
  elif command -v pacman >/dev/null 2>&1; then
    echo "pacman"
  elif command -v zypper >/dev/null 2>&1; then
    echo "zypper"
  elif command -v brew >/dev/null 2>&1 || [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
    echo "brew"
  else
    echo "unknown"
  fi
}

# Checks whether a CLI executable binary is available in the current PATH.
# Inputs: $1 - Command or binary name
# Outputs: Returns 0 if command is available and executable, 1 otherwise
is_package_installed() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1
}

# Checks whether Zsh binary is installed and executable in system PATH.
# Inputs: None
# Outputs: Returns 0 if zsh is executable, 1 otherwise
is_zsh_installed() {
  is_package_installed zsh && zsh --version >/dev/null 2>&1
}

# Installs a package on Linux using detected package manager with privilege escalation if needed.
# Inputs: $1 - Package name to install
# Outputs: None. Exits on installation failure.
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

  log_info "Installing $pkg via $pm..."
  case "$pm" in
    dnf)
      $sudo_cmd dnf install -y "$pkg" || die_install "dnf install $pkg failed"
      ;;
    apt-get)
      $sudo_cmd apt-get update && $sudo_cmd apt-get install -y "$pkg" || die_install "apt-get install $pkg failed"
      ;;
    yum)
      $sudo_cmd yum install -y "$pkg" || die_install "yum install $pkg failed"
      ;;
    pacman)
      $sudo_cmd pacman -S --noconfirm "$pkg" || die_install "pacman install $pkg failed"
      ;;
    zypper)
      $sudo_cmd zypper install -y "$pkg" || die_install "zypper install $pkg failed"
      ;;
    brew)
      local brew_bin="brew"
      [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]] && brew_bin="/home/linuxbrew/.linuxbrew/bin/brew"
      "$brew_bin" install "$pkg" || die_install "brew install $pkg failed"
      ;;
    *)
      die_install "No supported package manager detected on Linux to install $pkg"
      ;;
  esac
  log_info "$pkg installation complete"
}

# Installs Zsh package on Linux using detected package manager with privilege escalation if needed.
# Inputs: None
# Outputs: None. Exits on installation failure.
install_zsh_linux() {
  local pkg="${ZSH_PACKAGE_NAME:-zsh}"
  install_linux_package "$pkg"
  log_info "Zsh ready: $(zsh --version 2>&1 | head -1)"
}

# Verifies presence of Zsh on macOS or installs via Homebrew.
# Inputs: None
# Outputs: None. Exits on installation failure.
install_zsh_darwin() {
  if is_zsh_installed; then
    log_info "Zsh already available: $(zsh --version 2>&1 | head -1)"
    return 0
  fi
  if command -v brew >/dev/null 2>&1; then
    log_info "Installing zsh via Homebrew..."
    brew install zsh || die_install "brew install zsh failed"
  else
    die_install "Zsh missing on macOS and Homebrew is not available"
  fi
}

# Ensures Zsh binary is installed on the host system.
# Inputs: $1 - Force flag (0 or 1)
# Outputs: None
ensure_zsh() {
  local force="${1:-0}"
  if is_zsh_installed && [[ "$force" != "1" ]]; then
    log_info "Zsh already installed: $(zsh --version 2>&1 | head -1)"
    return 0
  fi
  local os
  os="$(detect_os)"
  case "$os" in
    darwin)
      install_zsh_darwin
      ;;
    linux)
      install_zsh_linux
      ;;
    *)
      die_preflight "Unsupported OS for automated Zsh installation: $os"
      ;;
  esac
}

# Ensures nano editor binary is installed on the host system.
# Inputs: $1 - Force flag (0 or 1)
# Outputs: None
ensure_nano() {
  local force="${1:-0}"
  if is_package_installed nano && [[ "$force" != "1" ]]; then
    log_info "Nano already installed: $(nano --version 2>&1 | head -1)"
    return 0
  fi
  local os
  os="$(detect_os)"
  case "$os" in
    darwin)
      if command -v brew >/dev/null 2>&1; then
        log_info "Installing nano via Homebrew..."
        brew install nano || die_install "brew install nano failed"
      else
        log_info "Nano present at $(command -v nano)"
      fi
      ;;
    linux)
      install_linux_package "${NANO_PACKAGE_NAME:-nano}"
      ;;
    *)
      die_preflight "Unsupported OS for automated Nano installation: $os"
      ;;
  esac
}

# Strips previously written env-setup hook blocks from a zshrc file.
# Inputs: $1 - Path to zshrc file
# Outputs: Modifies target zshrc file in-place
strip_zshrc_env_hooks() {
  local zshrc="$1"
  local tmp="${zshrc}.env-setup-strip.$$"
  awk '
    /# >>> env-setup >>>/ { skip=1; next }
    /# <<< env-setup >>>/ { skip=0; next }
    /# >>> env-setup groovy >>>/ { skip=1; next }
    /# <<< env-setup groovy >>>/ { skip=0; next }
    !skip { print }
  ' "$zshrc" > "$tmp"
  mv "$tmp" "$zshrc"
}

# Installs or refreshes the unified env-setup source hook inside ~/.zshrc.
# Inputs: None
# Outputs: Modifies ~/.zshrc
ensure_zshrc_hook() {
  local env_file="$ENV_SETUP_ROOT/env-setup.env.zsh"
  local zshrc="${HOME}/.zshrc"
  if [[ ! -f "$env_file" ]]; then
    die_preflight "Missing unified env file: $env_file"
  fi
  if [[ ! -f "$zshrc" ]]; then
    touch "$zshrc"
  fi
  strip_zshrc_env_hooks "$zshrc"
  {
    echo ""
    echo "$ZSHRC_HOOK_BEGIN"
    echo "source \"$env_file\""
    echo "$ZSHRC_HOOK_END"
  } >> "$zshrc"
  log_info "Updated ~/.zshrc env-setup hook"
  if grep -qE 'openjdk(@[0-9]+)?/bin' "$zshrc" 2>/dev/null; then
    log_warn "Consider removing bare openjdk PATH lines from ~/.zshrc (now managed by switchGroovy/switchJava)"
  fi
}

# Displays usage help text for the shell setup script.
# Inputs: None
# Outputs: Prints help text to stdout
show_shell_setup_help() {
  cat << 'EOF'
Usage: setup.sh [options]

Bootstrap shell environment, install Zsh and Nano if absent, and configure unified hook in ~/.zshrc.

Options:
  -h, --help               Show this help and exit
      --skip-zsh-install   Skip automated Zsh package installation
      --skip-nano-install  Skip automated Nano package installation
      --force              Reinstall packages even if already present
      --verbose            Enable debug logging

Examples:
  ./setup.sh
  ./setup.sh --skip-nano-install

Related:
  ./verify.sh
  ../env-setup.env.zsh
EOF
}

# Displays usage help text for the shell verification script.
# Inputs: None
# Outputs: Prints help text to stdout
show_shell_verify_help() {
  cat << 'EOF'
Usage: verify.sh [options]

Verify Zsh and Nano installations, ~/.zshrc hook, and shell function runtime execution in zsh.

Options:
  -h, --help       Show this help and exit
      --verbose    Enable debug logging
EOF
}

# Validates prerequisite files and environment before shell setup/verify routines.
# Inputs: None
# Outputs: None. Exits on failure.
preflight_shell() {
  if [[ ! -f "$ENV_SETUP_ROOT/env-setup.env.zsh" ]]; then
    die_preflight "Missing env-setup.env.zsh at repo root"
  fi
  if [[ ! -f "$SHELL_SCRIPT_DIR/shell.env.zsh" ]]; then
    die_preflight "Missing shell/shell.env.zsh"
  fi
}