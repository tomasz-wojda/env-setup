#!/usr/bin/env bash
set -euo pipefail

JAVA_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GROOVY_SCRIPT_DIR="$(cd "$JAVA_SCRIPT_DIR/../groovy" && pwd)"
# shellcheck source=../groovy/lib/common.sh
source "$GROOVY_SCRIPT_DIR/lib/common.sh"
init_common
load_config

MAJOR_FILTER=""
ENV_SETUP_VERBOSE=0
FAILURES=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      echo "Usage: verify.sh [--major N] [--verbose]"
      exit 0
      ;;
    --major) MAJOR_FILTER="$2"; shift 2 ;;
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

check_dir() { [[ -d "$1" ]]; }
check_file() { [[ -f "$1" ]]; }
check_link() { [[ -L "$1" ]] && [[ -e "$1" ]]; }

check "JAVA_ROOT exists" check_dir "$JAVA_ROOT"
check "versions.conf exists" check_file "$JAVA_SCRIPT_DIR/versions.conf"

majors="$JAVA_INITIAL_MAJORS"
[[ -n "$MAJOR_FILTER" ]] && majors="$MAJOR_FILTER"

for major in $majors; do
  jdk_id="openjdk-$major"
  jhome="$(java_home_for_id "$jdk_id")"
  if is_valid_java_home "$jhome"; then
    log_info "OK: $jdk_id at $jhome"
  else
    log_error "FAIL: $jdk_id at $jhome"
    FAILURES=$((FAILURES + 1))
  fi
done

check "java/current symlink" check_link "$JAVA_ROOT/current"

if [[ -L "$JAVA_ROOT/current" ]]; then
  jh="$(cd "$JAVA_ROOT/current" && pwd -P)"
  if is_valid_java_home "$jh" 2>/dev/null && "$jh/bin/java" -version >/dev/null 2>&1; then
    log_info "OK: java -version via current ($("$jh/bin/java" -version 2>&1 | head -1))"
  else
    log_error "FAIL: java -version via current"
    FAILURES=$((FAILURES + 1))
  fi
fi

if [[ "$FAILURES" -gt 0 ]]; then
  die_validate "$FAILURES check(s) failed"
fi
log_info "All checks passed."
