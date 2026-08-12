#!/usr/bin/env bash
set -euo pipefail

BREW_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$BREW_SCRIPT_DIR/lib/common.sh"
init_brew_common

DRY_RUN=0
ENV_SETUP_VERBOSE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) show_install_homebrew_help; exit 0 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --verbose) ENV_SETUP_VERBOSE=1; shift ;;
    *) die_usage "Unknown option: $1 (try --help)" ;;
  esac
done

preflight_brew
install_homebrew "$DRY_RUN"
