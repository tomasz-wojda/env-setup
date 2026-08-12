#!/usr/bin/env bash
set -euo pipefail

JAVA_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GROOVY_SCRIPT_DIR="$(cd "$JAVA_SCRIPT_DIR/../groovy" && pwd)"
# shellcheck source=../groovy/lib/common.sh
source "$GROOVY_SCRIPT_DIR/lib/common.sh"
init_common
load_config

JDK_ARG=""
DO_ALL=0
DRY_RUN=0
FORCE=0
ENV_SETUP_VERBOSE=0

if [[ $# -eq 0 ]]; then
  show_update_java_help
  exit 1
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) show_update_java_help; exit 0 ;;
    --all) DO_ALL=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    --force) FORCE=1; shift ;;
    --verbose) ENV_SETUP_VERBOSE=1; shift ;;
    17) JDK_ARG="openjdk-17"; shift ;;
    21) JDK_ARG="openjdk-21"; shift ;;
    25) JDK_ARG="openjdk-25"; shift ;;
    26) JDK_ARG="openjdk-26"; shift ;;
    *) die_usage "Unknown option: $1 (try --help)" ;;
  esac
done

preflight_common "$DRY_RUN" 1

if [[ "$DO_ALL" == "1" ]]; then
  update_jdk_all "$FORCE" "$DRY_RUN"
  exit 0
fi

[[ -n "$JDK_ARG" ]] || die_usage "JDK major required (17, 21, 25, or 26) unless using --all"

update_jdk "$JDK_ARG" "$FORCE" "$DRY_RUN"
