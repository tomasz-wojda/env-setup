#!/usr/bin/env bash
# Bootstraps the shell environment by installing Zsh and Nano, and configuring ~/.zshrc.
set -euo pipefail

SHELL_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_SETUP_ROOT="$(cd "$SHELL_SCRIPT_DIR/.." && pwd)"
# shellcheck source=lib/common.sh
source "$SHELL_SCRIPT_DIR/lib/common.sh"
init_shell_common

SKIP_ZSH_INSTALL=0
SKIP_NANO_INSTALL=0
FORCE=0
ENV_SETUP_VERBOSE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) show_shell_setup_help; exit 0 ;;
    --skip-zsh-install) SKIP_ZSH_INSTALL=1; shift ;;
    --skip-nano-install) SKIP_NANO_INSTALL=1; shift ;;
    --force) FORCE=1; shift ;;
    --verbose) ENV_SETUP_VERBOSE=1; shift ;;
    *) die_usage "Unknown option: $1 (try --help)" ;;
  esac
done

preflight_shell

if [[ "$SKIP_ZSH_INSTALL" != "1" ]]; then
  ensure_zsh "$FORCE"
fi

if [[ "$SKIP_NANO_INSTALL" != "1" ]]; then
  ensure_nano "$FORCE"
fi

ensure_zshrc_hook

log_info "Shell setup complete."
log_info "Next: source ~/.zshrc or launch zsh"