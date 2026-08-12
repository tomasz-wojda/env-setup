#!/usr/bin/env bash
set -euo pipefail

GROOVY_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$GROOVY_SCRIPT_DIR/lib/common.sh"
init_common
load_config

SKIP_JDK=0
SKIP_DOWNLOAD=0
MAJOR_FILTER=""
ENV_SETUP_VERBOSE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) show_setup_help; exit 0 ;;
    --skip-jdk) SKIP_JDK=1; shift ;;
    --skip-download) SKIP_DOWNLOAD=1; shift ;;
    --major) MAJOR_FILTER="$2"; shift 2 ;;
    --verbose) ENV_SETUP_VERBOSE=1; shift ;;
    *) die_usage "Unknown option: $1 (try --help)" ;;
  esac
done

preflight_common "$SKIP_DOWNLOAD" "$SKIP_JDK"

majors="$GROOVY_INITIAL_MAJORS"
if [[ -n "$MAJOR_FILTER" ]]; then
  majors="$MAJOR_FILTER"
fi

if [[ "$SKIP_JDK" != "1" ]]; then
  "$GROOVY_SCRIPT_DIR/../java/setup.sh"
fi

for major in $majors; do
  var="GROOVY_VERSION_$major"
  pin="$(pinned_version_for_major "$major")"
  printf -v "$var" '%s' "$pin"
  if [[ "$SKIP_DOWNLOAD" != "1" ]]; then
    installed="$(install_groovy_version "$pin")"
    printf -v "$var" '%s' "$installed"
  fi
done

write_versions_conf

default_ver="$(version_for_major "$GROOVY_DEFAULT_MAJOR")"
set_current_groovy "$default_ver"

"$GROOVY_SCRIPT_DIR/../shell/setup.sh"

log_info "Setup complete."
log_info "Installed Groovy majors: $GROOVY_INITIAL_MAJORS"
log_info "Active: Groovy $GROOVY_DEFAULT_MAJOR ($default_ver)"
log_info "Next: source ~/.zshrc && ../java/verify.sh && ./verify.sh && groovy6"
