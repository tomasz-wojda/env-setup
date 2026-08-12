#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_SETUP_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=../java/config.defaults
source "$ENV_SETUP_ROOT/java/config.defaults"
# shellcheck source=../groovy/config.defaults
source "$ENV_SETUP_ROOT/groovy/config.defaults"
[[ -n "${ENV_SETUP_JAVA_ROOT:-}" ]] && JAVA_ROOT="$ENV_SETUP_JAVA_ROOT"
[[ -n "${ENV_SETUP_GROOVY_ROOT:-}" ]] && GROOVY_ROOT="$ENV_SETUP_GROOVY_ROOT"
if [[ -f "$ENV_SETUP_ROOT/groovy/versions.conf" ]]; then
  # shellcheck source=../groovy/versions.conf
  source "$ENV_SETUP_ROOT/groovy/versions.conf"
fi

GROOVY_FILTER=""
FAILED_MAJORS=0
SKIPPED_MAJORS=0
TESTED_MAJORS=0

usage() {
  cat << 'EOF'
Usage: test-all-groovy-jdks.sh [options]

Run scripts/test-groovy-jdks.sh for each installed Groovy major (3, 4, 5, 6).

Options:
  -h, --help       Show this help and exit
      --major N    Limit to Groovy major N (3, 4, 5, or 6)

Examples:
  ./scripts/test-all-groovy-jdks.sh
  ./scripts/test-all-groovy-jdks.sh --major 3
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --major) GROOVY_FILTER="$2"; shift 2 ;;
    *) echo "ERROR: Unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

majors="$GROOVY_INITIAL_MAJORS"
[[ -n "$GROOVY_FILTER" ]] && majors="$GROOVY_FILTER"

echo "Groovy root: $GROOVY_ROOT"
echo "Java root:   $JAVA_ROOT"
echo "JDKs:        $JAVA_IDS"
echo ""

for major in $majors; do
  var="GROOVY_VERSION_$major"
  ver="${!var:-}"
  if [[ -z "$ver" ]]; then
    echo "Groovy $major: SKIP (no version in versions.conf)"
    SKIPPED_MAJORS=$((SKIPPED_MAJORS + 1))
    echo ""
    continue
  fi

  gh="$GROOVY_ROOT/groovy-$ver"
  if [[ ! -x "$gh/bin/groovy" ]]; then
    echo "Groovy $major: SKIP (not installed at $gh)"
    SKIPPED_MAJORS=$((SKIPPED_MAJORS + 1))
    echo ""
    continue
  fi

  echo "════════════════════════════════════════"
  printf " Groovy major %s (%s)\n" "$major" "$ver"
  echo "════════════════════════════════════════"

  if "$SCRIPT_DIR/test-groovy-jdks.sh" "$gh"; then
    TESTED_MAJORS=$((TESTED_MAJORS + 1))
  else
    TESTED_MAJORS=$((TESTED_MAJORS + 1))
    FAILED_MAJORS=$((FAILED_MAJORS + 1))
  fi
  echo ""
done

echo "Matrix: $TESTED_MAJORS tested · $FAILED_MAJORS failed · $SKIPPED_MAJORS skipped"

if [[ "$FAILED_MAJORS" -gt 0 ]]; then
  exit 1
fi

if [[ "$TESTED_MAJORS" -eq 0 ]]; then
  exit 1
fi

exit 0
