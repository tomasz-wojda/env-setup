#!/usr/bin/env bash
set -euo pipefail

BREW_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$BREW_SCRIPT_DIR/lib/common.sh"
init_brew_common

ENV_SETUP_VERBOSE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) show_verify_brew_help; exit 0 ;;
    --verbose) ENV_SETUP_VERBOSE=1; shift ;;
    *) die_usage "Unknown option: $1 (try --help)" ;;
  esac
done

preflight_brew
ensure_brew_in_path || die_preflight "Homebrew not available"
verify_formulae
