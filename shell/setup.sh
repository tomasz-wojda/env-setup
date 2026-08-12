#!/usr/bin/env bash
set -euo pipefail

SHELL_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_SETUP_ROOT="$(cd "$SHELL_SCRIPT_DIR/.." && pwd)"
# shellcheck source=lib/common.sh
source "$SHELL_SCRIPT_DIR/lib/common.sh"
init_shell_common

ENV_SETUP_VERBOSE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) show_shell_setup_help; exit 0 ;;
    --verbose) ENV_SETUP_VERBOSE=1; shift ;;
    *) die_usage "Unknown option: $1 (try --help)" ;;
  esac
done

preflight_shell
ensure_zshrc_hook

log_info "Shell setup complete."
log_info "Next: source ~/.zshrc"
