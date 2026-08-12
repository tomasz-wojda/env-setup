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
Runs groovy -v and executes a small Groovy script on each JDK.

Arguments:
  groovy-path    Groovy install dir (e.g. /opt/groovy/groovy-4.0.33)
                 or path to bin/groovy

Examples:
  ./scripts/test-groovy-jdks.sh /opt/groovy/groovy-4.0.33
  ./scripts/test-groovy-jdks.sh /opt/groovy/groovy-3.0.22
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

format_groovy_runtime() {
  local line="$1"
  local formatted
  formatted="$(printf '%s' "$line" | sed -n 's/.*Groovy Version: \([^ ]*\) JVM: \([^ ]*\).*/Groovy \1 · JVM \2/p')"
  if [[ -n "$formatted" ]]; then
    printf '%s' "$formatted"
  else
    printf '%s' "$line"
  fi
}

extract_run_error() {
  local out="$1"
  local msg

  msg="$(printf '%s\n' "$out" | grep -oE 'Unsupported class file major version [0-9]+' | head -1)"
  if [[ -n "$msg" ]]; then
    printf '%s' "$msg"
    return 0
  fi

  msg="$(printf '%s\n' "$out" | sed -n 's/^Caught: //p' | head -1)"
  if [[ -n "$msg" ]]; then
    printf '%s' "$msg"
    return 0
  fi

  msg="$(printf '%s\n' "$out" | sed -n 's/^Caused by: //p' | head -1)"
  if [[ -n "$msg" ]]; then
    printf '%s' "$msg"
    return 0
  fi

  printf '%s\n' "$out" | grep -v '^[[:space:]]*at ' | grep -v '^$' | head -1
}

test_jdk() {
  local jdk_id="$1"
  local jhome="$JAVA_ROOT/$jdk_id"
  local major="${jdk_id#openjdk-}"
  local tmp ver_out run_out runtime error

  if [[ ! -x "$jhome/bin/java" || ! -d "$jhome/lib" ]]; then
    printf "  %-3s   %-4s   %s\n" "$major" "SKIP" "not installed"
    SKIPPED=$((SKIPPED + 1))
    return 0
  fi

  tmp="$(mktemp "${TMPDIR:-/tmp}/groovy-jdk-test.XXXXXX.groovy")"
  printf '%s\n' 'println "ok"' 'println System.getProperty("java.version")' > "$tmp"

  if ! ver_out="$(JAVA_HOME="$jhome" GROOVY_HOME="$GROOVY_HOME" "$GROOVY_HOME/bin/groovy" -v 2>&1)"; then
    error="$(extract_run_error "$ver_out")"
    printf "  %-3s   %-4s   %s\n" "$major" "FAIL" "groovy -v failed"
    printf "                  └ %s\n" "$error"
    rm -f "$tmp"
    FAILURES=$((FAILURES + 1))
    return 0
  fi

  runtime="$(format_groovy_runtime "$ver_out")"

  if run_out="$(JAVA_HOME="$jhome" GROOVY_HOME="$GROOVY_HOME" "$GROOVY_HOME/bin/groovy" "$tmp" 2>&1)"; then
    printf "  %-3s   %-4s   %s\n" "$major" "OK" "$runtime"
    PASSED=$((PASSED + 1))
  else
    error="$(extract_run_error "$run_out")"
    printf "  %-3s   %-4s   %s\n" "$major" "FAIL" "$runtime"
    printf "                  └ %s\n" "$error"
    FAILURES=$((FAILURES + 1))
  fi

  rm -f "$tmp"
}

[[ $# -eq 1 && "$1" != "-h" && "$1" != "--help" ]] || {
  usage
  exit "$([[ $# -eq 0 ]] && echo 1 || echo 0)"
}

resolve_groovy_home "$1"

echo "Groovy: $(basename "$GROOVY_HOME") @ $GROOVY_HOME"
echo "Java:   $JAVA_ROOT"
echo ""
printf "  %-3s   %-4s   %s\n" "JDK" "TEST" "RUNTIME"
printf "  %-3s   %-4s   %s\n" "---" "----" "-------"

for jdk_id in $JAVA_IDS; do
  test_jdk "$jdk_id"
done

echo ""
echo "$PASSED passed · $FAILURES failed · $SKIPPED skipped"

if [[ "$FAILURES" -gt 0 ]]; then
  exit 1
fi

if [[ "$PASSED" -eq 0 ]]; then
  exit 1
fi

exit 0
