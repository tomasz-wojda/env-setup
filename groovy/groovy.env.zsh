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

_ensure_jdk_link() {
  local jdk_id="$1"
  local home="$JAVA_ROOT/$jdk_id"
  local pkg src

  [[ -x "$home/bin/java" && -d "$home/lib" ]] && return 0

  case "$jdk_id" in
    openjdk-17) pkg="openjdk@17" ;;
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

_groovy_normalize_version() {
  local v="$1"
  [[ "$v" == groovy-* ]] || v="groovy-$v"
  print -r -- "${v#groovy-}"
}

_groovy_jdk_id_for_major() {
  local major="$1"
  local param="GROOVY_JDK_${major}"
  print -r -- ${(P)param}
}

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

switchGroovy() {
  local version="$(_groovy_normalize_version "$1")"
  local target="$GROOVY_ROOT/groovy-$version"
  local major="${version%%.*}"

  echo "switching to groovy: $1"

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

  echo "JAVA_HOME=$JAVA_HOME"
  echo "GROOVY_HOME=$GROOVY_HOME"
  groovy -v
}

unalias groovy3 groovy4 groovy5 groovy6 java17 java25 java26 2>/dev/null

groovy3() { switchGroovy "$GROOVY_VERSION_3"; }
groovy4() { switchGroovy "$GROOVY_VERSION_4"; }
groovy5() { switchGroovy "$GROOVY_VERSION_5"; }
groovy6() { switchGroovy "$GROOVY_VERSION_6"; }

java17() { switchJava openjdk-17; }
java25() { switchJava openjdk-25; }
java26() { switchJava openjdk-26; }

default_var="GROOVY_VERSION_${GROOVY_DEFAULT_MAJOR}"
switchGroovy ${(P)default_var}
