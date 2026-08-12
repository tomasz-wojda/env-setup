#!/usr/bin/env bash
set -euo pipefail

GROOVY_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$GROOVY_SCRIPT_DIR/lib/common.sh"
init_common
load_config

MAJOR=""
DO_ALL=0
DO_CLEAN=0
CLEAN_ONLY=0
CLEAN_ALL=0
DRY_RUN=0
FORCE=0
ROLLBACK=0
ENV_SETUP_VERBOSE=0

if [[ $# -eq 0 ]]; then
  show_update_groovy_help
  exit 1
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) show_update_groovy_help; exit 0 ;;
    --all) DO_ALL=1; shift ;;
    --clean) DO_CLEAN=1; shift ;;
    --clean-only) CLEAN_ONLY=1; shift ;;
    --clean-all) CLEAN_ALL=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    --force) FORCE=1; shift ;;
    --rollback) ROLLBACK=1; shift ;;
    --verbose) ENV_SETUP_VERBOSE=1; shift ;;
    [3456]) MAJOR="$1"; shift ;;
    *) die_usage "Unknown option or major: $1 (try --help)" ;;
  esac
done

preflight_common "$DRY_RUN" 1

if [[ "$CLEAN_ALL" == "1" ]]; then
  if [[ "$DRY_RUN" == "1" ]]; then
    log_info "[dry-run] would clean all majors"
    exit 0
  fi
  clean_groovy_all
  exit 0
fi

if [[ "$CLEAN_ONLY" == "1" ]]; then
  [[ -n "$MAJOR" ]] || die_usage "--clean-only requires major (3-6)"
  if [[ "$DRY_RUN" == "1" ]]; then
    log_info "[dry-run] would clean major $MAJOR"
    exit 0
  fi
  clean_groovy_major "$MAJOR"
  exit 0
fi

if [[ "$DO_ALL" == "1" ]]; then
  for major in $GROOVY_INITIAL_MAJORS; do
    if [[ "$ROLLBACK" == "1" ]]; then
      rollback_groovy_major "$major" "$DRY_RUN"
    else
      update_groovy_major "$major" "$DO_CLEAN" "$FORCE" "$DRY_RUN"
    fi
  done
  exit 0
fi

[[ -n "$MAJOR" ]] || die_usage "Major required (3-6) unless using --all or --clean-all"

if [[ "$ROLLBACK" == "1" ]]; then
  rollback_groovy_major "$MAJOR" "$DRY_RUN"
  exit 0
fi

update_groovy_major "$MAJOR" "$DO_CLEAN" "$FORCE" "$DRY_RUN"
