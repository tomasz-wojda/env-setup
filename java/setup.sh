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

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) show_java_setup_help; exit 0 ;;
    --major) MAJOR_FILTER="$2"; shift 2 ;;
    --verbose) ENV_SETUP_VERBOSE=1; shift ;;
    *) die_usage "Unknown option: $1 (try --help)" ;;
  esac
done

preflight_common 1 0

majors="$JAVA_INITIAL_MAJORS"
[[ -n "$MAJOR_FILTER" ]] && majors="$MAJOR_FILTER"

for major in $majors; do
  ensure_jdk "openjdk-$major"
done

set_current_java "openjdk-${JAVA_DEFAULT_MAJOR}"
write_java_versions_conf

log_info "Java setup complete."
log_info "Installed JDK majors: $JAVA_INITIAL_MAJORS"
log_info "Active: JDK $JAVA_DEFAULT_MAJOR"
log_info "Next: source ~/.zshrc && java${JAVA_DEFAULT_MAJOR}"
