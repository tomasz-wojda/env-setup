#!/usr/bin/env bash
# Homebrew environment configuration, package lifecycle management, and verification functions.

# Loads default and local Homebrew configuration parameters.
# Inputs: None
# Outputs: None
load_brew_config() {
  if [[ -z "${BREW_SCRIPT_DIR:-}" ]]; then
    BREW_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[1]:-${BASH_SOURCE[0]}}")/.." && pwd)"
  fi
  # shellcheck source=../config.defaults
  source "$BREW_SCRIPT_DIR/config.defaults"
  if [[ -f "$BREW_SCRIPT_DIR/config.local.sh" ]]; then
    # shellcheck source=/dev/null
    source "$BREW_SCRIPT_DIR/config.local.sh"
  fi
}

# Initializes the Homebrew library subsystem, resolving dependencies and configs.
# Inputs: None
# Outputs: None
init_brew_common() {
  # shellcheck source=logging.sh
  source "$BREW_SCRIPT_DIR/lib/logging.sh"
  load_brew_config
}

# Detects host operating system kernel and normalizes the OS name.
# Inputs: None (reads uname -s)
# Outputs: Echoes normalized OS identifier ('darwin', 'linux', 'unknown')
detect_os() {
  case "$(uname -s)" in
    Darwin) echo "darwin" ;;
    Linux) echo "linux" ;;
    *) echo "unknown" ;;
  esac
}

# Ensures Homebrew binary directory is in PATH across macOS and Linux installations.
# Inputs: None
# Outputs: Returns 0 if brew is found and environment loaded, 1 otherwise
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

# Checks whether Homebrew binary is installed and executable in PATH.
# Inputs: None
# Outputs: Returns 0 if brew command is available, 1 otherwise
brew_installed() {
  command -v brew >/dev/null 2>&1
}

# Checks whether a specific formula is currently installed via Homebrew.
# Inputs: $1 - Formula package name
# Outputs: Returns 0 if installed, 1 otherwise
formula_installed() {
  local formula="$1"
  brew list --formula "$formula" >/dev/null 2>&1
}

# Installs Homebrew onto the system if not already present.
# Inputs: $1 - Dry run flag (0 or 1)
# Outputs: None. Exits on installation failure.
install_homebrew() {
  local dry_run="${1:-0}"
  if brew_installed; then
    log_info "Homebrew already installed: $(brew --version | head -1)"
    return 0
  fi
  local os
  os="$(detect_os)"
  if [[ "$os" != "darwin" && "$os" != "linux" ]]; then
    die_preflight "Homebrew automated install supports macOS and Linux only"
  fi
  if [[ "$dry_run" == "1" ]]; then
    log_info "[dry-run] would install Homebrew from $BREW_INSTALL_URL"
    return 0
  fi
  log_info "Installing Homebrew..."
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL "$BREW_INSTALL_URL")" || die_install "Homebrew installation failed"
  ensure_brew_in_path || die_install "Homebrew installed but brew command not found in PATH"
  log_info "Homebrew installed: $(brew --version | head -1)"
  if [[ -x /opt/homebrew/bin/brew ]]; then
    log_info "Add to shell profile if needed: eval \"\$(/opt/homebrew/bin/brew shellenv)\""
  elif [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
    log_info "Add to shell profile if needed: eval \"\$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)\""
  fi
}

# Ensures a specific formula package is installed via Homebrew.
# Inputs: $1 - Formula name, $2 - Force reinstall flag (0 or 1)
# Outputs: None. Exits on failure.
ensure_formula() {
  local formula="$1"
  local force="${2:-0}"
  if formula_installed "$formula" && [[ "$force" != "1" ]]; then
    log_info "$formula already installed"
    return 0
  fi
  log_info "Installing $formula..."
  brew install -y "$formula" || die_install "brew install $formula failed"
  log_info "$formula installed"
}

# Installs all configured formulae defined in BREW_FORMULAE.
# Inputs: $1 - Force reinstall flag (0 or 1)
# Outputs: None
ensure_formulae() {
  local force="${1:-0}"
  local formula
  for formula in $BREW_FORMULAE; do
    ensure_formula "$formula" "$force"
  done
}

# Checks whether a specific cask application is installed via Homebrew.
# Inputs: $1 - Cask name
# Outputs: Returns 0 if installed, 1 otherwise
cask_installed() {
  local cask="$1"
  brew list --cask "$cask" >/dev/null 2>&1
}

# Ensures a specific cask application is installed on macOS.
# Inputs: $1 - Cask name, $2 - Force reinstall flag (0 or 1)
# Outputs: None
ensure_cask() {
  local cask="$1"
  local force="${2:-0}"
  if [[ "$(detect_os)" != "darwin" ]]; then
    log_info "Cask $cask is macOS-only (skipping on Linux)"
    return 0
  fi
  if cask_installed "$cask" && [[ "$force" != "1" ]]; then
    log_info "$cask already installed"
    return 0
  fi
  log_info "Installing $cask..."
  brew install -y --cask "$cask" || die_install "brew install --cask $cask failed"
  log_info "$cask installed"
}

# Installs all configured casks defined in BREW_CASKS on macOS.
# Inputs: $1 - Force reinstall flag (0 or 1)
# Outputs: None
ensure_casks() {
  local force="${1:-0}"
  local cask
  if [[ "$(detect_os)" != "darwin" ]]; then
    log_info "Casks are macOS-only (skipping on Linux)"
    return 0
  fi
  for cask in $BREW_CASKS; do
    ensure_cask "$cask" "$force"
  done
}

tfenv_version_installed() {
  local version="$1"
  [[ -x "${HOME}/.config/tfenv/versions/${version}/terraform" ]]
}

ensure_tfenv_versions() {
  local force="${1:-0}"
  local version
  [[ -n "${BREW_TFENV_VERSIONS:-}" ]] || return 0
  command -v tfenv >/dev/null 2>&1 || die_install "tfenv required to install Terraform versions"
  for version in $BREW_TFENV_VERSIONS; do
    if tfenv_version_installed "$version" && [[ "$force" != "1" ]]; then
      log_info "Terraform $version already installed via tfenv"
    else
      log_info "Installing Terraform $version via tfenv..."
      tfenv install "$version" || die_install "tfenv install $version failed"
      log_info "Terraform $version installed via tfenv"
    fi
  done
  if [[ -n "${BREW_TFENV_DEFAULT:-}" ]]; then
    log_info "Setting default Terraform version to $BREW_TFENV_DEFAULT..."
    tfenv use "$BREW_TFENV_DEFAULT" || die_install "tfenv use $BREW_TFENV_DEFAULT failed"
  fi
}

# Updates all configured formulae to their latest versions.
# Inputs: $1 - Dry run flag (0 or 1)
# Outputs: None
update_formulae() {
  local dry_run="${1:-0}"
  if [[ "$dry_run" == "1" ]]; then
    log_info "[dry-run] would run brew update and brew upgrade for: $BREW_FORMULAE"
    return 0
  fi
  log_info "Running brew update..."
  brew update || log_warn "brew update failed (continuing)"
  local formula
  for formula in $BREW_FORMULAE; do
    if formula_installed "$formula"; then
      log_info "Upgrading $formula..."
      brew upgrade -y "$formula" 2>/dev/null || log_info "$formula already at latest"
    else
      ensure_formula "$formula" 0
    fi
  done
}

# Updates all configured casks to their latest versions on macOS.
# Inputs: $1 - Dry run flag (0 or 1)
# Outputs: None
update_casks() {
  local dry_run="${1:-0}"
  if [[ "$(detect_os)" != "darwin" ]]; then
    return 0
  fi
  if [[ "$dry_run" == "1" ]]; then
    log_info "[dry-run] would run brew update and brew upgrade --cask for: $BREW_CASKS"
    return 0
  fi
  log_info "Running brew update..."
  brew update || log_warn "brew update failed (continuing)"
  local cask
  for cask in $BREW_CASKS; do
    if cask_installed "$cask"; then
      log_info "Upgrading $cask..."
      brew upgrade -y --cask "$cask" 2>/dev/null || log_info "$cask already at latest"
    else
      ensure_cask "$cask" 0
    fi
  done
}

# Upgrades all configured formulae and casks.
# Inputs: $1 - Dry run flag (0 or 1)
# Outputs: None
update_brew_packages() {
  local dry_run="${1:-0}"
  update_formulae "$dry_run"
  update_casks "$dry_run"
}

# Returns list of installed configured formulae that have newer versions available.
# Inputs: None
# Outputs: Echoes space-separated list of outdated formulae
configured_outdated_formulae() {
  local formula outdated=""
  for formula in $BREW_FORMULAE; do
    if formula_installed "$formula" && brew outdated --formula "$formula" 2>/dev/null | grep -q .; then
      outdated="${outdated}${formula} "
    fi
  done
  echo "$outdated"
}

# Returns list of installed configured casks that have newer versions available on macOS.
# Inputs: None
# Outputs: Echoes space-separated list of outdated casks
configured_outdated_casks() {
  local cask outdated=""
  if [[ "$(detect_os)" != "darwin" ]]; then
    echo ""
    return 0
  fi
  for cask in $BREW_CASKS; do
    if cask_installed "$cask" && brew outdated --cask "$cask" 2>/dev/null | grep -q .; then
      outdated="${outdated}${cask} "
    fi
  done
  echo "$outdated"
}

# Verifies that Homebrew and all configured formulae are installed and reported.
# Inputs: None
# Outputs: None. Exits on validation failure.
verify_formulae() {
  local failures=0
  local formula
  if ! brew_installed; then
    die_validate "Homebrew not installed"
  fi
  log_info "Homebrew: $(brew --version | head -1)"
  for formula in $BREW_FORMULAE; do
    if formula_installed "$formula"; then
      log_info_brew_item_ok "$formula"
    else
      log_error_brew_item_fail "$formula"
      failures=$((failures + 1))
    fi
  done
  local outdated
  outdated="$(configured_outdated_formulae)"
  if [[ -n "$outdated" ]]; then
    log_warn "Outdated formulae: $outdated"
  else
    log_info "OK: configured formulae up to date"
  fi
  if [[ "$failures" -gt 0 ]]; then
    return 1
  fi
}

# Verifies that configured casks are installed on macOS.
# Inputs: None
# Outputs: None. Exits on validation failure.
verify_casks() {
  local failures=0
  local cask
  if [[ "$(detect_os)" != "darwin" ]]; then
    log_info "Casks: macOS only (skipped on Linux)"
    return 0
  fi
  for cask in $BREW_CASKS; do
    if cask_installed "$cask"; then
      log_info_brew_item_ok "$cask"
    else
      log_error_brew_item_fail "$cask"
      failures=$((failures + 1))
    fi
  done
  local outdated
  outdated="$(configured_outdated_casks)"
  if [[ -n "$outdated" ]]; then
    log_warn "Outdated casks: $outdated"
  elif [[ -n "$BREW_CASKS" ]]; then
    log_info "OK: configured casks up to date"
  fi
  if [[ "$failures" -gt 0 ]]; then
    return 1
  fi
}

verify_tfenv_versions() {
  local failures=0
  local version
  [[ -n "${BREW_TFENV_VERSIONS:-}" ]] || return 0
  if ! command -v tfenv >/dev/null 2>&1; then
    log_error "FAIL: tfenv not installed (required for Terraform)"
    return 1
  fi
  for version in $BREW_TFENV_VERSIONS; do
    if tfenv_version_installed "$version"; then
      log_info_brew_item_ok "terraform" "$version installed via tfenv"
    else
      log_error_brew_item_fail "terraform" "$version not installed via tfenv"
      failures=$((failures + 1))
    fi
  done
  if command -v terraform >/dev/null 2>&1; then
    log_info "OK: terraform on PATH ($("terraform" version 2>&1 | head -1))"
  else
    log_error "FAIL: terraform not on PATH"
    failures=$((failures + 1))
  fi
  if [[ "$failures" -gt 0 ]]; then
    return 1
  fi
}

# Runs formula and cask verification checks.
# Inputs: None
# Outputs: None
verify_brew_packages() {
  local failures=0
  verify_formulae || failures=$((failures + 1))
  verify_tfenv_versions || failures=$((failures + 1))
  verify_casks || failures=$((failures + 1))
  if [[ "$failures" -gt 0 ]]; then
    die_validate "$failures brew check group(s) failed"
  fi
  log_info "All brew checks passed."
}

# Displays usage help text for the Homebrew installer script.
# Inputs: None
# Outputs: Prints help text to stdout
show_install_homebrew_help() {
  cat << 'EOF'
Usage: install-homebrew.sh [options]

Install Homebrew on macOS or Linux if not already present.

Options:
  -h, --help       Show this help and exit
      --dry-run    Show planned actions only
      --verbose    Enable debug logging

Examples:
  ./install-homebrew.sh
  ./install-homebrew.sh --dry-run

Related:
  ./setup.sh --help
EOF
}

# Displays usage help text for the Homebrew package setup script.
# Inputs: None
# Outputs: Prints help text to stdout
show_brew_setup_help() {
  cat << 'EOF'
Usage: setup.sh [options]

Install configured Homebrew formulae and casks (tree, gh, kubectl, helm, tfenv, python3, argocd, nano, etc.).
Terraform versions are installed via tfenv (see BREW_TFENV_VERSIONS in config.defaults).

Options:
  -h, --help           Show this help and exit
      --with-homebrew  Install Homebrew first if missing (default)
      --skip-homebrew  Skip Homebrew install check
      --package NAME       Install one formula (with configured set unless --skip-configured)
      --cask NAME          Install one cask (with configured set unless --skip-configured; macOS only)
      --skip-configured    Skip configured formulae and casks; use with --package or --cask
      --list           Print configured formulae and casks and exit
      --force          Reinstall configured formulae and casks
      --verbose        Enable debug logging

Examples:
  ./setup.sh
  ./setup.sh --package jq
  ./setup.sh --package helm --skip-configured
  ./setup.sh --package tfenv --skip-configured
  ./setup.sh --list

Related:
  ./install-homebrew.sh --help
  ../groovy/setup.sh
EOF
}

# Displays usage help text for the Homebrew update script.
# Inputs: None
# Outputs: Prints help text to stdout
show_update_brew_help() {
  cat << 'EOF'
Usage: update-brew.sh [options]

Run brew update and upgrade configured formulae and casks.

Options:
  -h, --help       Show this help and exit
      --dry-run    Show planned actions only
      --verbose    Enable debug logging

Examples:
  ./update-brew.sh
  ./update-brew.sh --dry-run
EOF
}

# Displays usage help text for the Homebrew verification script.
# Inputs: None
# Outputs: Prints help text to stdout
show_verify_brew_help() {
  cat << 'EOF'
Usage: verify.sh [options]

Verify Homebrew and configured formulae (and macOS casks) are installed.

Options:
  -h, --help       Show this help and exit
      --verbose    Enable debug logging
EOF
}

# Validates prerequisite operating system and loads brew environment into PATH.
# Inputs: None
# Outputs: None. Exits on unsupported OS.
preflight_brew() {
  local os
  os="$(detect_os)"
  if [[ "$os" != "darwin" && "$os" != "linux" ]]; then
    die_preflight "brew module supports macOS and Linux only (current OS: $os)"
  fi
  ensure_brew_in_path || true
}