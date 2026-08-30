#!/usr/bin/env bash
# Verifies Zsh and Nano installations, ~/.zshrc unified hook configuration, and shell function availability.
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

if is_zsh_installed; then
  log_info "OK: zsh binary present ($(zsh --version 2>&1 | head -1))"
else
  log_error "FAIL: zsh binary not found in PATH"
  FAILURES=$((FAILURES + 1))
fi

if is_package_installed nano; then
  log_info "OK: nano binary present ($(nano --version 2>&1 | head -1))"
else
  log_error "FAIL: nano binary not found in PATH"
  FAILURES=$((FAILURES + 1))
fi

check "env-setup.env.zsh exists" test -f "$ENV_SETUP_ROOT/env-setup.env.zsh"
check "shell.env.zsh exists" test -f "$SHELL_SCRIPT_DIR/shell.env.zsh"

if grep -qF "$ZSHRC_HOOK_BEGIN" "${HOME}/.zshrc" 2>/dev/null \
  && grep -qE 'source ".*env-setup\.env\.zsh"' "${HOME}/.zshrc" 2>/dev/null; then
  log_info "OK: ~/.zshrc unified env-setup hook"
else
  log_error "FAIL: ~/.zshrc unified env-setup hook"
  FAILURES=$((FAILURES + 1))
fi

shell_function_check_output() {
  if ! is_zsh_installed; then
    echo "error:zsh_missing"
    return 1
  fi
  zsh -i -c "
    source \"$ENV_SETUP_ROOT/env-setup.env.zsh\" >/dev/null 2>&1
    for fn in $SHELL_FUNCTIONS; do
      if whence -w \"\$fn\" 2>/dev/null | grep -q function; then
        print -r -- \"ok:\$fn\"
      else
        print -r -- \"fail:\$fn\"
      fi
    done
  " 2>&1
}

output="$(shell_function_check_output 2>/dev/null || true)"
if [[ -z "$output" ]]; then
  log_error "FAIL: zsh subshell execution produced no output"
  FAILURES=$((FAILURES + 1))
else
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    case "$line" in
      ok:*)
        fn="${line#ok:}"
        log_info_shell_function_ok "$fn"
        ;;
      fail:*)
        fn="${line#fail:}"
        log_error_shell_function_fail "$fn"
        FAILURES=$((FAILURES + 1))
        ;;
      error:*)
        err="${line#error:}"
        log_error "FAIL: shell function verification error ($err)"
        FAILURES=$((FAILURES + 1))
        ;;
      *)
        log_debug "zsh output: $line"
        ;;
    esac
  done <<< "$output"
fi

if [[ "$FAILURES" -gt 0 ]]; then
  die_validate "$FAILURES check(s) failed"
fi
log_info "All checks passed."