#!/usr/bin/env zsh
# Test suite verifying shell functions, aliases, and Groovy/Java switching within Zsh runtime.
set -eu

SCRIPT_DIR="${0:A:h}"
REPO_ROOT="${SCRIPT_DIR:h}"

if ! command -v zsh >/dev/null 2>&1; then
  echo "ERROR: zsh binary not found; run shell/setup.sh first" >&2
  exit 1
fi

echo "Running shell function and environment test suite in Zsh..."
echo "Zsh version: $(zsh --version)"
echo "Repo root:   $REPO_ROOT"
echo ""

source "$REPO_ROOT/env-setup.env.zsh"

PASSED=0
FAILED=0

assert_func() {
  local name="$1"
  if whence -w "$name" 2>/dev/null | grep -q function; then
    echo "  [OK] function '$name' defined"
    PASSED=$((PASSED + 1))
  else
    echo "  [FAIL] function '$name' missing"
    FAILED=$((FAILED + 1))
  fi
}

echo "=== Testing Shell Utility Functions ==="
for fn in ls ssh gss glo gcam switchGroovy switchJava groovy3 groovy4 groovy5 groovy6 java17 java25 java26; do
  assert_func "$fn"
done

echo ""
echo "=== Testing gcam dry-run ==="
output="$(gcam --dry-run 'test message')"
if echo "$output" | grep -q 'would run: git commit -am "test message"'; then
  echo "  [OK] gcam --dry-run formatted command properly"
  PASSED=$((PASSED + 1))
else
  echo "  [FAIL] gcam --dry-run unexpected output: $output"
  FAILED=$((FAILED + 1))
fi

echo ""
echo "=== Testing Environment Switching Functions ==="
for major in 3 4 5 6; do
  "groovy$major" >/dev/null
  if [[ -n "$GROOVY_HOME" && -d "$GROOVY_HOME" && -n "$JAVA_HOME" && -d "$JAVA_HOME" ]]; then
    echo "  [OK] groovy$major activated (JAVA_HOME=$JAVA_HOME, GROOVY_HOME=$GROOVY_HOME)"
    PASSED=$((PASSED + 1))
  else
    echo "  [FAIL] groovy$major failed to set valid environment"
    FAILED=$((FAILED + 1))
  fi
done

echo ""
echo "Test Results: $PASSED passed · $FAILED failed"
if [[ "$FAILED" -gt 0 ]]; then
  exit 1
fi