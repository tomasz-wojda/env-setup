#!/usr/bin/env bash
set -euo pipefail

SHELL_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_SETUP_ROOT="$(cd "$SHELL_SCRIPT_DIR/.." && pwd)"
# shellcheck source=lib/common.sh
source "$SHELL_SCRIPT_DIR/lib/common.sh"
init_shell_common

ENV_SETUP_VERBOSE=0
FAILURES=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) show_shell_verify_help; exit 0 ;;
    --verbose) ENV_SETUP_VERBOSE=1; shift ;;
    *) die_usage "Unknown option: $1" ;;
  esac
done

check() {
  local msg="$1"
  shift
  if "$@"; then
    log_info "OK: $msg"
  else
    log_error "FAIL: $msg"
    FAILURES=$((FAILURES + 1))
  fi
}

preflight_shell

check "env-setup.env.zsh exists" test -f "$ENV_SETUP_ROOT/env-setup.env.zsh"
check "shell.env.zsh exists" test -f "$SHELL_SCRIPT_DIR/shell.env.zsh"

if grep -qF "$ZSHRC_HOOK_BEGIN" "${HOME}/.zshrc" 2>/dev/null \
  && grep -qF "$ENV_SETUP_ROOT/env-setup.env.zsh" "${HOME}/.zshrc" 2>/dev/null; then
  log_info "OK: ~/.zshrc unified env-setup hook"
else
  log_error "FAIL: ~/.zshrc unified env-setup hook"
  FAILURES=$((FAILURES + 1))
fi

if zsh -i -c "source \"$ENV_SETUP_ROOT/env-setup.env.zsh\" >/dev/null 2>&1; whence -w gcam" 2>/dev/null | grep -q 'function'; then
  log_info "OK: gcam loads as zsh function"
else
  log_error "FAIL: gcam loads as zsh function"
  FAILURES=$((FAILURES + 1))
fi

if [[ "$FAILURES" -gt 0 ]]; then
  die_validate "$FAILURES check(s) failed"
fi
log_info "All checks passed."
