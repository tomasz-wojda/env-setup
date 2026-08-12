#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_SETUP_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=../java/config.defaults
source "$ENV_SETUP_ROOT/java/config.defaults"
[[ -n "${ENV_SETUP_JAVA_ROOT:-}" ]] && JAVA_ROOT="$ENV_SETUP_JAVA_ROOT"

GROOVY_HOME=""
FAILURES=0
PASSED=0
SKIPPED=0

usage() {
  cat << 'EOF'
Usage: test-groovy-jdks.sh <groovy-path>

Test a Groovy installation against all configured JDKs under /opt/java.

Arguments:
  groovy-path    Groovy install dir (e.g. /opt/groovy/groovy-4.0.33)
                 or path to bin/groovy

Examples:
  ./scripts/test-groovy-jdks.sh /opt/groovy/groovy-4.0.33
  ./scripts/test-groovy-jdks.sh /opt/groovy/current
EOF
}

resolve_groovy_home() {
  local input="$1"
  local path="$input"

  if [[ -f "$path" && -x "$path" ]]; then
    path="$(cd "$(dirname "$path")/.." && pwd)"
  elif [[ -d "$path" ]]; then
    path="$(cd "$path" && pwd)"
  else
    echo "ERROR: Groovy path not found: $input" >&2
    exit 1
  fi

  if [[ ! -x "$path/bin/groovy" ]]; then
    echo "ERROR: Missing executable: $path/bin/groovy" >&2
    exit 1
  fi

  GROOVY_HOME="$path"
}

test_jdk() {
  local jdk_id="$1"
  local jhome="$JAVA_ROOT/$jdk_id"
  local major="${jdk_id#openjdk-}"

  if [[ ! -x "$jhome/bin/java" || ! -d "$jhome/lib" ]]; then
    echo "=== JDK $major === SKIP (not installed at $jhome)"
    SKIPPED=$((SKIPPED + 1))
    return 0
  fi

  echo "=== JDK $major ==="
  if out="$(JAVA_HOME="$jhome" GROOVY_HOME="$GROOVY_HOME" "$GROOVY_HOME/bin/groovy" -v 2>&1)"; then
    echo "$out"
    PASSED=$((PASSED + 1))
  else
    echo "FAIL: $out"
    FAILURES=$((FAILURES + 1))
  fi
}

[[ $# -eq 1 && "$1" != "-h" && "$1" != "--help" ]] || {
  usage
  exit "$([[ $# -eq 0 ]] && echo 1 || echo 0)"
}

resolve_groovy_home "$1"

echo "Groovy: $GROOVY_HOME"
echo "Java root: $JAVA_ROOT"
echo ""

for jdk_id in $JAVA_IDS; do
  test_jdk "$jdk_id"
done

echo ""
echo "Passed: $PASSED  Failed: $FAILURES  Skipped: $SKIPPED"

if [[ "$PASSED" -eq 0 ]]; then
  exit 1
fi

exit 0
