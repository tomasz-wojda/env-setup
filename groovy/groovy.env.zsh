_groovy_env_dir="${0:A:h}"
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

_refresh_groovy_path() {
  local p
  _groovy_path_reply=()
  for p in $path; do
    [[ "$p" == "$JAVA_ROOT"/openjdk-*/bin ]] && continue
    [[ "$p" == "$JAVA_ROOT"/*/bin ]] && continue
    [[ "$p" == "$GROOVY_ROOT"/groovy-*/bin ]] && continue
    [[ "$p" == "$GROOVY_ROOT"/current/bin ]] && continue
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

alias groovy3='switchGroovy ${GROOVY_VERSION_3}'
alias groovy4='switchGroovy ${GROOVY_VERSION_4}'
alias groovy5='switchGroovy ${GROOVY_VERSION_5}'
alias groovy6='switchGroovy ${GROOVY_VERSION_6}'

default_var="GROOVY_VERSION_${GROOVY_DEFAULT_MAJOR}"
switchGroovy ${(P)default_var}
