#!/usr/bin/env bash
set -euo pipefail

BREW_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$BREW_SCRIPT_DIR/lib/common.sh"
init_brew_common

WITH_HOMEBREW=1
SKIP_HOMEBREW=0
EXTRA_PACKAGE=""
EXTRA_CASK=""
LIST_ONLY=0
FORCE=0
ENV_SETUP_VERBOSE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) show_brew_setup_help; exit 0 ;;
    --with-homebrew) WITH_HOMEBREW=1; shift ;;
    --skip-homebrew) SKIP_HOMEBREW=1; shift ;;
    --package) EXTRA_PACKAGE="$2"; shift 2 ;;
    --cask) EXTRA_CASK="$2"; shift 2 ;;
    --list) LIST_ONLY=1; shift ;;
    --force) FORCE=1; shift ;;
    --verbose) ENV_SETUP_VERBOSE=1; shift ;;
    *) die_usage "Unknown option: $1 (try --help)" ;;
  esac
done

if [[ "$LIST_ONLY" == "1" ]]; then
  echo "Configured formulae: $BREW_FORMULAE"
  echo "Configured casks: $BREW_CASKS"
  exit 0
fi

preflight_brew

if [[ "$SKIP_HOMEBREW" != "1" && "$WITH_HOMEBREW" == "1" ]]; then
  install_homebrew 0
fi

ensure_brew_in_path || die_preflight "Homebrew not available (run ./install-homebrew.sh)"

ensure_formulae "$FORCE"
ensure_casks "$FORCE"

if [[ -n "$EXTRA_PACKAGE" ]]; then
  ensure_formula "$EXTRA_PACKAGE" "$FORCE"
fi

if [[ -n "$EXTRA_CASK" ]]; then
  ensure_cask "$EXTRA_CASK" "$FORCE"
fi

log_info "Brew setup complete."
log_info "Formulae: $BREW_FORMULAE${EXTRA_PACKAGE:+ $EXTRA_PACKAGE}"
log_info "Casks: $BREW_CASKS${EXTRA_CASK:+ $EXTRA_CASK}"
log_info "Next: ../groovy/setup.sh"
