# Groovy and Java runtime environment switcher and interactive shell functions for Zsh.

_groovy_env_dir="${0:A:h}"
# shellcheck source=../java/config.defaults
source "$_groovy_env_dir/../java/config.defaults"
# shellcheck source=config.defaults
source "$_groovy_env_dir/config.defaults"
if [[ -f "$_groovy_env_dir/config.local.sh" ]]; then
  # shellcheck source=config.local.sh
  source "$_groovy_env_dir/config.local.sh"
fi
[[ -n "${ENV_SETUP_JAVA_ROOT:-}" ]] && JAVA_ROOT="$ENV_SETUP_JAVA_ROOT"
[[ -n "${ENV_SETUP_GROOVY_ROOT:-}" ]] && GROOVY_ROOT="$ENV_SETUP_GROOVY_ROOT"
if [[ -f "$_groovy_env_dir/versions.conf" ]]; then
  # shellcheck source=versions.conf
  source "$_groovy_env_dir/versions.conf"
fi

typeset -a _groovy_path_reply

# Validates and repairs the JDK link from Homebrew cellars on macOS if missing.
# Inputs: $1 - JDK identifier
# Outputs: Returns 0 if valid link exists, 1 otherwise
_ensure_jdk_link() {
  local jdk_id="$1"
  local home="$JAVA_ROOT/$jdk_id"
  local pkg src

  [[ -x "$home/bin/java" && -d "$home/lib" ]] && return 0

  case "$jdk_id" in
    openjdk-17) pkg="openjdk@17" ;;
    openjdk-21) pkg="openjdk@21" ;;
    openjdk-25) pkg="openjdk@25" ;;
    openjdk-26) pkg="openjdk" ;;
    *) return 1 ;;
  esac

  command -v brew >/dev/null 2>&1 || return 1
  brew list "$pkg" >/dev/null 2>&1 || return 1

  src="$(brew --prefix "$pkg")/libexec/openjdk.jdk/Contents/Home"
  [[ -x "$src/bin/java" && -d "$src/lib" ]] || return 1

  ln -sfn "$src" "$home"
}

# Re-orders PATH elements to prioritize active JAVA_HOME and GROOVY_HOME binaries.
# Inputs: None
# Outputs: Modifies $path array
_refresh_groovy_path() {
  local p
  _groovy_path_reply=()
  for p in $path; do
    [[ "$p" == "$JAVA_ROOT"/openjdk-*/bin ]] && continue
    [[ "$p" == "$JAVA_ROOT"/*/bin ]] && continue
    [[ "$p" == "$GROOVY_ROOT"/groovy-*/bin ]] && continue
    [[ "$p" == "$GROOVY_ROOT"/current/bin ]] && continue
    [[ "$p" == /opt/homebrew/opt/openjdk@*/bin ]] && continue
    [[ "$p" == /opt/homebrew/opt/openjdk/bin ]] && continue
    _groovy_path_reply+=("$p")
  done
  path=("$JAVA_HOME/bin" "$GROOVY_HOME/bin" "${_groovy_path_reply[@]}")
}

# Normalizes a Groovy version string by stripping leading prefixes.
# Inputs: $1 - Version string
# Outputs: Echoes normalized version
_groovy_normalize_version() {
  local v="$1"
  [[ "$v" == groovy-* ]] || v="groovy-$v"
  print -r -- "${v#groovy-}"
}

# Resolves configured JDK identifier for a Groovy major version.
# Inputs: $1 - Groovy major number
# Outputs: Echoes JDK identifier
_groovy_jdk_id_for_major() {
  local major="$1"
  local param="GROOVY_JDK_${major}"
  print -r -- ${(P)param}
}

# Determines highest configured Groovy major mapped to a JDK identifier.
# Inputs: $1 - JDK identifier
# Outputs: Echoes Groovy major number
_highest_groovy_major_for_jdk() {
  local jdk_id="$1"
  local major result=""
  for major in ${=GROOVY_INITIAL_MAJORS}; do
    local param="GROOVY_JDK_${major}"
    [[ "${(P)param}" == "$jdk_id" ]] && result="$major"
  done
  [[ -n "$result" ]] || return 1
  print -r -- "$result"
}

# Returns compact version number of active java binary.
# Inputs: $1 - Java home path
# Outputs: Echoes java version string
_java_version_short() {
  local home="$1"
  "$home/bin/java" -version 2>&1 | head -1 | sed -E 's/.*version "([^"]+)".*/\1/'
}

# Outputs environment activation summary banner to terminal.
# Inputs: $1 - Active Groovy version string
# Outputs: Prints banner to stdout
_print_env_conjuring() {
  local groovy_version="$1"
  local java_version
  java_version="$(_java_version_short "$JAVA_HOME")"
  print -r -- ">>> Conjuring env-setup: Groovy ${groovy_version} · JDK ${java_version}"
  if [[ "${ENV_SETUP_VERBOSE:-0}" == "1" ]]; then
    print -r -- "JAVA_HOME=$JAVA_HOME"
    print -r -- "GROOVY_HOME=$GROOVY_HOME"
    groovy -v
  fi
}

# Switches active Java JDK and paired Groovy major version.
# Inputs: $1 - JDK identifier (e.g. "openjdk-17")
# Outputs: Activates JDK and paired Groovy environment
switchJava() {
  local jdk_id="$1"
  local home="$JAVA_ROOT/$jdk_id"
  local major ver_param

  if [[ ! -x "$home/bin/java" || ! -d "$home/lib" ]]; then
    _ensure_jdk_link "$jdk_id"
  fi

  if [[ ! -x "$home/bin/java" || ! -d "$home/lib" ]]; then
    print -u2 "ERROR: JDK not found at $home"
    return 1
  fi

  major="$(_highest_groovy_major_for_jdk "$jdk_id")" || {
    print -u2 "ERROR: No Groovy major mapped to $jdk_id"
    return 1
  }

  ver_param="GROOVY_VERSION_${major}"
  switchGroovy "${(P)ver_param}"
}

# Switches active Groovy installation, updates current symlinks, exports JAVA_HOME, and updates PATH.
# Inputs: $1 - Groovy version or major identifier
# Outputs: Activates Groovy and paired JDK environment
switchGroovy() {
  local version="$(_groovy_normalize_version "$1")"
  local target="$GROOVY_ROOT/groovy-$version"
  local major="${version%%.*}"

  if [[ ! -d "$target" ]]; then
    print -u2 "ERROR: Groovy not found at $target"
    return 1
  fi

  rm -f "$GROOVY_ROOT/current"
  ln -sfn "$target" "$GROOVY_ROOT/current"

  local jdk_id="$(_groovy_jdk_id_for_major "$major")"
  _ensure_jdk_link "$jdk_id"
  export JAVA_HOME="$JAVA_ROOT/$jdk_id"
  export GROOVY_HOME="$GROOVY_ROOT/current"

  if [[ ! -x "$JAVA_HOME/bin/java" || ! -d "$JAVA_HOME/lib" ]]; then
    print -u2 "ERROR: Invalid JAVA_HOME: $JAVA_HOME"
    return 1
  fi
  if [[ ! -x "$GROOVY_HOME/bin/groovy" ]]; then
    print -u2 "ERROR: Invalid GROOVY_HOME: $GROOVY_HOME"
    return 1
  fi

  rm -f "$JAVA_ROOT/current"
  ln -sfn "$JAVA_HOME" "$JAVA_ROOT/current"

  _refresh_groovy_path

  _print_env_conjuring "$version"
}

unalias groovy3 groovy4 groovy5 groovy6 java17 java25 java26 2>/dev/null || true

groovy3() { switchGroovy "$GROOVY_VERSION_3"; }
groovy4() { switchGroovy "$GROOVY_VERSION_4"; }
groovy5() { switchGroovy "$GROOVY_VERSION_5"; }
groovy6() { switchGroovy "$GROOVY_VERSION_6"; }

java17() { switchJava openjdk-17; }
java25() { switchJava openjdk-25; }
java26() { switchJava openjdk-26; }

default_var="GROOVY_VERSION_${GROOVY_DEFAULT_MAJOR}"
switchGroovy ${(P)default_var}