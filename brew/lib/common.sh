#!/usr/bin/env bash

load_brew_config() {
  if [[ -z "${BREW_SCRIPT_DIR:-}" ]]; then
    BREW_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[1]:-${BASH_SOURCE[0]}}")/.." && pwd)"
  fi
  # shellcheck source=/dev/null
  source "$BREW_SCRIPT_DIR/config.defaults"
  if [[ -f "$BREW_SCRIPT_DIR/config.local.sh" ]]; then
    # shellcheck source=/dev/null
    source "$BREW_SCRIPT_DIR/config.local.sh"
  fi
}

init_brew_common() {
  # shellcheck source=logging.sh
  source "$BREW_SCRIPT_DIR/lib/logging.sh"
  load_brew_config
}

detect_os() {
  case "$(uname -s)" in
    Darwin) echo "darwin" ;;
    Linux) echo "linux" ;;
    *) echo "unknown" ;;
  esac
}

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
  return 1
}

brew_installed() {
  command -v brew >/dev/null 2>&1
}

formula_installed() {
  local formula="$1"
  brew list --formula "$formula" >/dev/null 2>&1
}

install_homebrew() {
  local dry_run="${1:-0}"
  if brew_installed; then
    log_info "Homebrew already installed: $(brew --version | head -1)"
    return 0
  fi
  if [[ "$(detect_os)" != "darwin" ]]; then
    die_preflight "Homebrew install is macOS-only"
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
    log_info "Add to ~/.zprofile if needed: eval \"\$(/opt/homebrew/bin/brew shellenv)\""
  fi
}

ensure_formula() {
  local formula="$1"
  local force="${2:-0}"
  if formula_installed "$formula" && [[ "$force" != "1" ]]; then
    log_info "$formula already installed"
    return 0
  fi
  log_info "Installing $formula..."
  brew install "$formula" || die_install "brew install $formula failed"
  log_info "$formula installed"
}

ensure_formulae() {
  local force="${1:-0}"
  local formula
  for formula in $BREW_FORMULAE; do
    ensure_formula "$formula" "$force"
  done
}

cask_installed() {
  local cask="$1"
  brew list --cask "$cask" >/dev/null 2>&1
}

ensure_cask() {
  local cask="$1"
  local force="${2:-0}"
  if cask_installed "$cask" && [[ "$force" != "1" ]]; then
    log_info "$cask already installed"
    return 0
  fi
  log_info "Installing $cask..."
  brew install --cask "$cask" || die_install "brew install --cask $cask failed"
  log_info "$cask installed"
}

ensure_casks() {
  local force="${1:-0}"
  local cask
  for cask in $BREW_CASKS; do
    ensure_cask "$cask" "$force"
  done
}

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
      brew upgrade "$formula" 2>/dev/null || log_info "$formula already at latest"
    else
      ensure_formula "$formula" 0
    fi
  done
}

update_casks() {
  local dry_run="${1:-0}"
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
      brew upgrade --cask "$cask" 2>/dev/null || log_info "$cask already at latest"
    else
      ensure_cask "$cask" 0
    fi
  done
}

update_brew_packages() {
  local dry_run="${1:-0}"
  update_formulae "$dry_run"
  update_casks "$dry_run"
}

verify_formulae() {
  local failures=0
  local formula
  if ! brew_installed; then
    die_validate "Homebrew not installed"
  fi
  log_info "Homebrew: $(brew --version | head -1)"
  for formula in $BREW_FORMULAE; do
    if formula_installed "$formula"; then
      log_info "OK: $formula installed"
    else
      log_error "FAIL: $formula not installed"
      failures=$((failures + 1))
    fi
  done
  local outdated
  outdated="$(brew outdated --formula 2>/dev/null | tr '\n' ' ')"
  if [[ -n "$outdated" ]]; then
    log_warn "Outdated formulae: $outdated"
  else
    log_info "OK: configured formulae up to date"
  fi
  if [[ "$failures" -gt 0 ]]; then
    die_validate "$failures configured formula(e) missing"
  fi
}

verify_casks() {
  local failures=0
  local cask
  for cask in $BREW_CASKS; do
    if cask_installed "$cask"; then
      log_info "OK: $cask installed"
    else
      log_error "FAIL: $cask not installed"
      failures=$((failures + 1))
    fi
  done
  local outdated
  outdated="$(brew outdated --cask 2>/dev/null | tr '\n' ' ')"
  if [[ -n "$outdated" ]]; then
    log_warn "Outdated casks: $outdated"
  elif [[ -n "$BREW_CASKS" ]]; then
    log_info "OK: configured casks up to date"
  fi
  if [[ "$failures" -gt 0 ]]; then
    die_validate "$failures configured cask(s) missing"
  fi
}

verify_brew_packages() {
  verify_formulae
  verify_casks
  log_info "All brew checks passed."
}

show_install_homebrew_help() {
  cat << 'EOF'
Usage: install-homebrew.sh [options]

Install Homebrew on macOS if not already present.

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

show_brew_setup_help() {
  cat << 'EOF'
Usage: setup.sh [options]

Install configured Homebrew formulae and casks (tree, gh, awscli@2, kubectl, python3, nimble-commander, etc.).

Options:
  -h, --help           Show this help and exit
      --with-homebrew  Install Homebrew first if missing (default)
      --skip-homebrew  Skip Homebrew install check
      --package NAME   Install one additional formula
      --cask NAME      Install one additional cask
      --list           Print configured formulae and casks and exit
      --force          Reinstall configured formulae and casks
      --verbose        Enable debug logging

Examples:
  ./setup.sh
  ./setup.sh --package jq
  ./setup.sh --list

Related:
  ./install-homebrew.sh --help
  ../groovy/setup.sh
EOF
}

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

show_verify_brew_help() {
  cat << 'EOF'
Usage: verify.sh [options]

Verify Homebrew and configured formulae and casks are installed.

Options:
  -h, --help       Show this help and exit
      --verbose    Enable debug logging
EOF
}

preflight_brew() {
  if [[ "$(detect_os)" != "darwin" ]]; then
    die_preflight "brew module supports macOS only"
  fi
  ensure_brew_in_path || true
}
